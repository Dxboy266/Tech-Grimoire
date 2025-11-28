# FireFlow 规则引擎技术分析文档

## 一、引擎概述

### 1.1 什么是 FireFlow

FireFlow 是一个**数据库驱动的业务规则流程引擎**，用于将复杂的业务逻辑从 Java 代码中解耦到数据库配置中。它允许开发者通过配置数据库表来定义业务流程，而不是硬编码在代码里。

**核心理念**：
- 业务逻辑配置化：将 SQL、校验规则、业务流程存储在数据库表中
- 流程节点化：将复杂业务拆解为多个可配置的节点（Action）
- 动态执行：运行时从数据库加载配置并执行

### 1.2 典型使用场景

从 `mdmOrgCityQueryFindAll` 方法可以看到典型用法：

```java
// 传统方式：硬编码查询逻辑
// Page<MdmOrgCity> page = this.page(new Page<>(pageIndex, pageSize), new QueryWrapper<>(info));

// FireFlow 方式：配置化流程
IFlowResultCtn resultCtn = fireFlowFocus
    .add("info", info)                    // 添加输入参数
    .add("pageIndex", info.getPageIndex())
    .add("pageSize", info.getPageSize())
    .flow("usc_db_025")                   // 指定流程编码
    .fire();                              // 执行流程

// 获取最后一个节点的结果
List<IFlowResult> flowresult = resultCtn.flowResults();
String action = flowresult.get(resultCtn.flowResults().size() - 1).action();
ListResult<Map<String, Object>> result = resultCtn.flowContext().dataVolume().ext().get(action);
```

---

## 二、核心架构原理

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      业务层 (Service)                        │
│  fireFlowFocus.add("data", obj).flow("flowCode").fire()    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   FireFlow 引擎核心                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ FlowContext  │  │ ActionLoader │  │ FlowExecute  │     │
│  │  (数据总线)   │  │ (配置加载器)  │  │  (执行器)     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   数据库配置层                               │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ t_prc_db_datarule    │  │ t_prc_db_sence_      │        │
│  │  (规则定义表)         │  │  datarule (流程表)    │        │
│  │ - SQL 内容            │  │ - 流程编码            │        │
│  │ - 操作类型            │  │ - 节点顺序            │        │
│  └──────────────────────┘  └──────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件说明

#### 2.2.1 IFireFlowFocus（流程构建器）

**职责**：提供流式 API 构建流程执行上下文

```java
public interface IFireFlowFocus {
    IFireFlowFocus flow(String flow);           // 指定流程编码
    IFireFlowFocus add(String dataNode, Object obj); // 添加数据
    IFireFlowFocus brand(String brand);         // 指定品牌
    IFlowResultCtn fire();                      // 执行流程
    IFlowResultCtn fireExcpt();                 // 执行并抛出异常
}
```

**实现原理**：
- 使用 `ThreadLocal` 存储临时数据，避免线程安全问题
- 采用建造者模式，支持链式调用
- `fire()` 方法触发实际执行，调用 `IFireFlow.fire()`

#### 2.2.2 IFireFlow（流程引擎核心）

**职责**：流程执行的总控制器

**关键方法**：
```java
public IFlowResultCtn fire(String flow, String brand, Map<String, Object> data) {
    String rid = StringHelper.GetGUID();              // 生成流程执行ID
    instrumentation.beginFlow(flow, brand, data, rid); // 监控埋点
    
    // 1. 构建执行上下文
    IFlowContext context = buildContext(flow, brand, data, rid);
    
    // 2. 执行流程
    result = flowExecute.process(context);
    
    // 3. 异常处理
    if (result.risultato().equals(Risultato.EXCPT)) {
        throw new RuntimeException(result.excpt());
    }
    
    return result;
}
```

**buildContext 核心逻辑**：
```java
public IFlowContext buildContext(String flow, String brand, Map<String, Object> data, String rid) {
    FlowContext context = FlowContext.create(flow, data);
    
    // 从数据库加载流程配置的所有节点
    List<IAction> actions = actionContainer.flowActions(flow, FlowUserMode.currentContext(brand));
    
    // 构建 SpEL 表达式上下文（用于动态取值）
    EvaluationContext sec = sec(context.dataVolume());
    
    // 为每个节点注入 SpEL 上下文
    actions.stream().forEach(action -> {
        action.extention().put(IAction.EXTKEY_SPEL, sec);
    });
    
    context.getFlowVolume().setActions(actions);
    return context;
}
```

#### 2.2.3 ActionContainer（配置容器）

**职责**：从数据库加载并缓存流程配置

**加载 SQL**：
```sql
SELECT 
    s.BUSINESSFLOW_SENCECODE,  -- 流程编码
    s.ACTION_CODE,              -- 节点编码
    s.ACTION_NAME,              -- 节点名称
    s.NEXT_ACTION_CODE,         -- 下一个节点
    s.LOOP_ENABLE,              -- 是否允许循环
    s.DATA_CODE,                -- 数据键
    r.OPERATION_TYPE,           -- 操作类型（SELECTLIST/INSERT/UPDATE等）
    s.MESSAGE_CODE,             -- 消息编码
    r.DATARULE_CHECK,           -- SQL 内容
    s.CAR_BRAND_CODE,           -- 品牌编码
    s.OEM_CODE,                 -- 厂商编码
    s.ACTION_FILTER,            -- 过滤器
    r.DATARULE_CODE             -- 规则编码
FROM t_prc_db_sence_datarule s 
RIGHT JOIN t_prc_db_datarule r 
    ON s.DATARULE_CODE = r.DATARULE_CODE 
WHERE r.IS_ENABLE = '1' AND s.IS_ENABLE = '1'
```

**缓存策略**：
- 启动时加载所有配置到内存（`@PostConstruct`）
- 按 `flow + brand + oemCode` 组合键缓存
- 支持客制化配置覆盖标准配置

#### 2.2.4 FlowExecute（流程执行器）

**职责**：按节点顺序递归执行流程

**核心执行逻辑**：
```java
public IFlowResultCtn process(IFlowContext context) {
    // 1. 查找 BEGIN 节点
    Optional<IAction> optional = context.flowVolume().actions()
        .stream()
        .filter(m -> START_ACTION.equals(m.action()))
        .findFirst();
    
    // 2. 递归执行节点
    IAction startAction = optional.get();
    invoke(startAction, context, result);
    
    return result;
}

boolean invoke(IAction action, IFlowContext context, IFlowResultCtn result) {
    // 防止死循环检测
    if (!action.loopEnble() && result.flowResults().stream()
            .filter(m -> m.action().equals(action.action()))
            .findFirst().isPresent()) {
        throw new FlowException("节点重复执行");
    }
    
    // 执行节点
    IActionExecute actionExecute = actionExecuteContainer.actionExecute(action.operation());
    actionResult = flowFilterExecute.invoke(actionExecute, action, context);
    
    // 获取下一个节点
    String nextActionName = actionResult.nextAction();
    Optional<IAction> optional = flowVolume.actions()
        .stream()
        .filter(m -> nextActionName.equals(m.action()))
        .findFirst();
    
    // 递归执行下一个节点
    if (optional.isPresent()) {
        return invoke(optional.get(), context, flowResult);
    }
    
    return false;
}
```

#### 2.2.5 ActionExecute（节点执行器）

**职责**：执行具体的操作类型

**支持的操作类型**（OperationType）：
```java
public enum OperationType {
    SELECTONE,      // 查询单条记录
    SELECTLIST,     // 查询列表（支持分页）
    UPDATE,         // 更新数据
    DELETE,         // 删除数据
    INSERT,         // 插入数据
    DATACHECK,      // 数据校验
    FIELDCHECK,     // 字段校验
    FUNCTION,       // 自定义函数
    SPBEAN,         // Spring Bean 调用
    SCRIPT,         // 脚本执行
    FLOW            // 子流程调用
}
```

**SELECTLIST 执行器示例**：
```java
public class ActionExecuteSelectList extends ActionExecuteBase {
    @Override
    public IActionResult execute(IAction action, IDataVolume dataVolume) {
        // 1. 创建 MyBatis 动态 SQL 执行器
        BusicenSqlMapper busicenSqlMapper = BusicenSqlMapper.create();
        
        // 2. 获取数据（支持 SpEL 表达式）
        Object data = dataVolume;
        if (!StringUtils.isEmpty(action.extKey())) {
            data = FlowSpelUtil.spelGetData(action, action.extKey());
        }
        
        // 3. 包装用户信息（自动注入 oemCode、userId 等）
        data = wrapperUserData(data);
        
        // 4. 执行 SQL（action.content() 是数据库配置的 SQL）
        List<Map<String, Object>> listData = busicenSqlMapper.selectList(action.content(), data);
        
        // 5. 将结果存入数据总线
        dataVolume.ext().put(action.action(), listData);
        
        // 6. 返回下一个节点
        result.nextAction(defaultNextActionCode(action, null));
        return result;
    }
}
```

---

## 三、数据库配置详解

### 3.1 核心配置表

#### 表 1：t_prc_db_datarule（规则定义表）

**作用**：存储具体的 SQL 语句和操作类型

| 字段名 | 说明 | 示例 |
|--------|------|------|
| DATARULE_CODE | 规则编码（唯一标识） | `USC_DB_025_QUERY` |
| OPERATION_TYPE | 操作类型 | `SELECTLIST` |
| DATARULE_CHECK | SQL 内容 | `SELECT * FROM t_usc_mdm_org_city WHERE ...` |
| IS_ENABLE | 是否启用 | `1` |

#### 表 2：t_prc_db_sence_datarule（流程节点表）

**作用**：定义流程的节点顺序和关系

| 字段名 | 说明 | 示例 |
|--------|------|------|
| BUSINESSFLOW_SENCECODE | 流程编码 | `usc_db_025` |
| ACTION_CODE | 节点编码 | `BEGIN` / `QUERY` / `END` |
| ACTION_NAME | 节点名称 | `开始` / `查询城市` / `结束` |
| NEXT_ACTION_CODE | 下一个节点 | `QUERY` / `END` / `` |
| DATARULE_CODE | 关联的规则编码 | `USC_DB_025_QUERY` |
| CAR_BRAND_CODE | 品牌编码 | `` (空表示通用) |
| OEM_CODE | 厂商编码 | `` (空表示通用) |
| ACTION_FILTER | 过滤器链 | `datacheck;fieldcheck` |
| LOOP_ENABLE | 是否允许循环 | `0` |
| IS_ENABLE | 是否启用 | `1` |

### 3.2 配置示例：城市查询流程（usc_db_025）

**流程节点配置**：

```
BEGIN (开始节点)
  ↓
DATACHECK (数据校验)
  ↓
QUERY (执行查询)
  ↓
END (结束节点)
```

**数据库配置**：

```sql
-- 规则定义表
INSERT INTO t_prc_db_datarule VALUES (
    'USC_DB_025_QUERY',                    -- 规则编码
    'SELECTLIST',                          -- 操作类型
    'SELECT * FROM t_usc_mdm_org_city 
     WHERE oem_code = #{oemCode}
     AND city_name LIKE CONCAT('%', #{cityName}, '%')
     LIMIT #{pageIndex}, #{pageSize}',    -- SQL 内容
    '1'                                    -- 启用
);

-- 流程节点表
INSERT INTO t_prc_db_sence_datarule VALUES (
    'usc_db_025',      -- 流程编码
    'BEGIN',           -- 节点编码
    '开始',            -- 节点名称
    'QUERY',           -- 下一个节点
    NULL,              -- 无关联规则
    '',                -- 品牌（空=通用）
    '',                -- 厂商（空=通用）
    '',                -- 无过滤器
    '0',               -- 不允许循环
    '1'                -- 启用
);

INSERT INTO t_prc_db_sence_datarule VALUES (
    'usc_db_025',      
    'QUERY',           
    '查询城市',        
    'END',             
    'USC_DB_025_QUERY', -- 关联规则
    '',                
    '',                
    '',                
    '0',               
    '1'                
);

INSERT INTO t_prc_db_sence_datarule VALUES (
    'usc_db_025',      
    'END',             
    '结束',            
    '',                -- 无下一个节点
    NULL,              
    '',                
    '',                
    '',                
    '0',               
    '1'                
);
```

---

## 四、执行流程详解

### 4.1 完整执行时序图

```
Service                FireFlowFocus         FireFlow              ActionContainer       FlowExecute           ActionExecute
  │                         │                    │                        │                    │                     │
  │ add("info", obj)        │                    │                        │                    │                     │
  │────────────────────────>│                    │                        │                    │                     │
  │                         │                    │                        │                    │                     │
  │ flow("usc_db_025")      │                    │                        │                    │                     │
  │────────────────────────>│                    │                        │                    │                     │
  │                         │                    │                        │                    │                     │
  │ fire()                  │                    │                        │                    │                     │
  │────────────────────────>│                    │                        │                    │                     │
  │                         │ fire(flow, data)   │                        │                    │                     │
  │                         │───────────────────>│                        │                    │                     │
  │                         │                    │ flowActions(flow)      │                    │                     │
  │                         │                    │───────────────────────>│                    │                     │
  │                         │                    │<───────────────────────│                    │                     │
  │                         │                    │   List<IAction>        │                    │                     │
  │                         │                    │                        │                    │                     │
  │                         │                    │ process(context)       │                    │                     │
  │                         │                    │───────────────────────────────────────────>│                     │
  │                         │                    │                        │                    │ execute(action)     │
  │                         │                    │                        │                    │────────────────────>│
  │                         │                    │                        │                    │<────────────────────│
  │                         │                    │                        │                    │   result            │
  │                         │                    │<───────────────────────────────────────────│                     │
  │<────────────────────────│<───────────────────│                        │                    │                     │
  │   IFlowResultCtn        │                    │                        │                    │                     │
```

### 4.2 数据流转

**输入数据**：
```java
Map<String, Object> inputData = {
    "info": MdmOrgCityIn对象,
    "pageIndex": 1,
    "pageSize": 10
}
```

**数据总线（DataVolume）**：
```java
{
    "begin": inputData,           // 初始数据
    "ext": {                      // 扩展数据（节点执行结果）
        "QUERY": List<Map>,       // QUERY 节点的查询结果
        "bupks": []               // 主键发布列表
    },
    "end": {}                     // 结束数据
}
```

**输出结果**：
```java
IFlowResultCtn {
    risultato: FINISH,            // 执行状态
    flowResults: [                // 所有节点的执行结果
        {action: "BEGIN", ...},
        {action: "QUERY", data: List<Map>},
        {action: "END", ...}
    ],
    flowContext: {                // 执行上下文
        dataVolume: {...}         // 数据总线
    }
}
```

---

## 五、高级特性

### 5.1 SpEL 表达式支持

**场景**：动态获取嵌套数据

```java
// 配置中的 DATA_CODE 字段
"info.cityName"

// 引擎会自动解析为
FlowSpelUtil.spelGetData(action, "info.cityName")
// 等价于
dataVolume.begin().get("info").getCityName()
```

### 5.2 用户信息自动注入

**原理**：通过 CGLIB 动态代理包装数据对象

```java
public static Object wrapperUserData(Object data) {
    if (data instanceof Map) {
        Map map = (Map) data;
        map.put("__user", FlowUserMode.currentUser());  // 注入用户信息
        return map;
    }
    // 对象类型使用 CGLIB 代理
    return wrapperObj(data);
}
```

**效果**：SQL 中可以直接使用用户信息

```sql
SELECT * FROM t_table 
WHERE oem_code = #{__user.oemCode}    -- 自动获取当前用户的厂商编码
  AND creator = #{__user.userId}
```

### 5.3 过滤器链（Filter Chain）

**配置**：`ACTION_FILTER = "datacheck;fieldcheck"`

**执行顺序**：
```
datacheck 过滤器 
  → fieldcheck 过滤器 
    → <execution> 过滤器（实际执行）
```

**实现原理**：责任链模式

```java
public IActionResult invoke(IActionExecute actionExecute, IAction action, IFlowContext context) {
    Queue<String> filterQue = new LinkedBlockingQueue<>();
    filterQue.addAll(Arrays.asList(action.filter().split(";")));
    filterQue.add("<execution>");  // 最后添加执行过滤器
    
    FlowInvocation invocation = new FlowInvocation() {
        public FlowFilter invoker() {
            String statement = filterQue.remove();
            return flowFilterContainer.filter(statement);
        }
    };
    
    return invocation.invoker().invoke(invocation);
}
```

### 5.4 客制化配置覆盖

**原理**：支持 `_cust` 后缀表

```sql
-- 标准配置表
t_prc_db_datarule
t_prc_db_sence_datarule

-- 客制化配置表（优先级更高）
t_prc_db_datarule_cust
t_prc_db_sence_datarule_cust
```

**加载逻辑**：
```java
if (xruleConfig.xruleExtendCfg().currentCustMode()) {
    // 先加载客制化配置
    actionContainer.setFragmentsCust(actionLoadInDbCust());
}
// 再加载标准配置
actionContainer.setFragments(actionLoadInDb());

// 查询时优先使用客制化配置
Optional<Fragment> opt = fragmentsCust.stream()
    .filter(f -> ruleCode.equals(f.getRuleCode()))
    .findFirst();
if (opt.isPresent()) {
    return opt.get();  // 使用客制化配置
}
// 否则使用标准配置
return fragments.stream()...
```

### 5.5 动态 SQL 引擎（BusicenMbEngine）

**核心能力**：运行时动态构建 MyBatis MappedStatement

```java
public String selectDynamic(String sql, Class<?> parameterType) {
    String msId = newMsId(sql + parameterType, SqlCommandType.SELECT);
    if (hasMappedStatement(msId)) {
        return msId;  // 已缓存，直接返回
    }
    
    // 动态创建 SqlSource
    SqlSource sqlSource = languageDriver.createSqlSource(configuration, sql, parameterType);
    
    // 动态注册 MappedStatement
    newSelectMappedStatement(msId, sqlSource, Map.class);
    
    return msId;
}
```

**优势**：
- 无需编写 XML Mapper 文件
- 支持 MyBatis 动态 SQL 语法（`<if>`, `<foreach>` 等）
- 自动缓存，避免重复创建

---

## 六、配置位置汇总

### 6.1 核心配置类

| 配置类 | 路径 | 作用 |
|--------|------|------|
| FlowConfig | `ly.bucn.xrule/.../flow/FlowConfig.java` | Spring Bean 配置 |
| XruleConfig | `ly.bucn.xrule/.../config/XruleConfig.java` | 全局配置 |
| XruleDataCfg | `ly.bucn.xrule/.../config/XruleDataCfg.java` | 表名配置 |

### 6.2 数据库配置表

| 表名 | 作用 | 位置 |
|------|------|------|
| t_prc_db_datarule | 规则定义（SQL） | 数据库 |
| t_prc_db_sence_datarule | 流程节点定义 | 数据库 |
| t_prc_db_sence_validatecolum | 字段校验规则 | 数据库 |
| t_prc_db_log_model | 消息模板 | 数据库 |
| t_prc_msg_table_register | 主键发布配置 | 数据库 |

### 6.3 应用配置

**文件**：`configfiles/application-cloud.properties`

```properties
# MyBatis Plus 配置
mybatis-plus.mapperLocations=classpath:/mapper/*Mapper.xml
mybatis-plus.typeAliasesPackage=com.ly.mp.test.entity

# 数据库配置
write.mp.jdbc.url=jdbc:mysql://172.26.223.XX:3306/mp23
write.mp.jdbc.username=XX
write.mp.jdbc.password=XX

# 规则引擎调试开关
xrule.debug.enable=false
```

---

## 七、优缺点分析

### 7.1 优点

#### ✅ 1. 业务逻辑配置化
- **问题**：传统方式修改查询逻辑需要改代码、编译、发布
- **解决**：修改数据库配置即可生效，无需重启应用

#### ✅ 2. 复用性强
- 同一个流程可以被多个业务复用
- 通过品牌、厂商编码实现多租户隔离

#### ✅ 3. 可视化潜力
- 流程配置存储在数据库，可以开发可视化配置界面
- 非技术人员也能配置简单流程

#### ✅ 4. 动态 SQL 能力
- 无需编写 XML Mapper
- 支持 MyBatis 全部动态 SQL 语法

#### ✅ 5. 扩展性好
- 支持自定义 ActionExecute
- 支持自定义 Filter
- 支持客制化配置覆盖

### 7.2 缺点

#### ❌ 1. 学习成本高
- 新人需要理解流程、节点、规则等概念
- 调试困难，需要查数据库配置

#### ❌ 2. 性能开销
- 每次执行都需要查询数据库加载配置（虽然有缓存）
- 递归执行节点，调用栈深
- 动态创建 MyBatis MappedStatement 有性能损耗

#### ❌ 3. SQL 注入风险
- SQL 存储在数据库中，如果配置不当可能导致注入
- 缺少编译期检查

#### ❌ 4. 调试困难
- 异常堆栈深，难以定位问题
- 无法使用 IDE 断点调试 SQL
- 日志分散在多个节点

#### ❌ 5. 过度设计
- 对于简单的 CRUD 操作，引入引擎反而增加复杂度
- 配置表结构复杂，维护成本高

#### ❌ 6. 缺少类型安全
- SQL 参数和返回值都是 `Map<String, Object>`
- 容易出现 key 拼写错误

---

## 八、Linus 式评分与建议

### 8.1 核心判断

**这是个真问题还是臆想出来的？**

这个引擎试图解决的问题是**真实存在的**：
- 多租户场景下，不同客户的业务逻辑确实有差异
- 频繁修改查询条件确实需要发布代码

但解决方案**过度设计了**：
- 90% 的查询逻辑是稳定的，不需要动态配置
- 真正需要动态的部分可以用更简单的方式解决（如策略模式 + 配置文件）

### 8.2 品味评分

🔴 **垃圾级别**

**理由**：

#### 1. 数据结构错了

```java
// 这是什么鬼？
Map<String, Object> data = dataVolume.ext().get(action);
```

**问题**：
- 所有数据都是 `Map<String, Object>`，完全丢失了类型信息
- 你无法知道 `data` 里有什么字段，只能靠文档或猜测
- 编译器无法帮你检查错误

**正确做法**：
```java
// 定义明确的数据结构
public class CityQueryResult {
    private List<City> cities;
    private int totalCount;
    // getter/setter
}

CityQueryResult result = cityService.query(request);
```

#### 2. 特殊情况太多

```java
// 为什么需要这么多判断？
if (!StringUtils.isEmpty(action.extKey())) {
    data = FlowSpelUtil.spelGetData(action, action.extKey());
}
data = wrapperUserData(data);
if (action.extention().get(IAction.EXTKEY_EXCEL) != null) {
    // Excel 导出特殊处理
}
```

**问题**：
- 每个执行器都有一堆 if/else
- 这些特殊情况本应该通过更好的数据结构设计来消除

**正确做法**：
```java
// 用多态消除 if/else
interface DataSource {
    Object getData();
}

class DirectDataSource implements DataSource {
    public Object getData() { return dataVolume; }
}

class SpelDataSource implements DataSource {
    public Object getData() { return spelGetData(...); }
}
```

#### 3. 复杂度爆炸

```
Service 
  → FireFlowFocus 
    → FireFlow 
      → ActionContainer 
        → FlowExecute 
          → FlowFilterExecute 
            → ActionExecute 
              → BusicenSqlMapper 
                → BusicenMbEngine 
                  → MyBatis
```

**问题**：
- 9 层调用栈！
- 每一层都在做"聪明"的事情，但组合起来就是灾难
- 调试时你需要在 9 个类之间跳转

**正确做法**：
```java
// 3 层足够了
Service 
  → QueryExecutor 
    → MyBatis
```

#### 4. 破坏性风险

```java
// 这段代码会破坏什么？
public static Object wrapperUserData(Object data) {
    if (data instanceof Map) {
        Map map = (Map) data;
        map.put("__user", FlowUserMode.currentUser());  // 直接修改原始 Map！
        return map;
    }
}
```

**问题**：
- 直接修改传入的 Map，违反了不可变性原则
- 如果调用方后续还要使用这个 Map，会得到被污染的数据
- 这种隐式修改极难调试

**正确做法**：
```java
// 创建新的 Map
public static Map<String, Object> wrapperUserData(Map<String, Object> data) {
    Map<String, Object> wrapped = new HashMap<>(data);
    wrapped.put("__user", FlowUserMode.currentUser());
    return wrapped;
}
```

### 8.3 实用性验证

**这个问题在生产环境真实存在吗？**

从代码中看到：
- `mdmOrgCityQueryFindAll` 使用了引擎
- `mdmOrgProvinceQueryFindAll` **没有**使用引擎，直接用 MyBatis Plus

```java
// 省份查询：直接用 MyBatis Plus（简单清晰）
IPage<MdmOrgProvince> page = new Page<>(info.getPageIndex(), info.getPageSize());
List<MdmOrgProvince> list = mdmOrgProvinceMapper.mdmOrgProvinceQueryFindAll(mdmOrgProvince, page);
```

**结论**：
- 引擎的使用率很低
- 大部分查询还是用传统方式
- 说明引擎并没有解决真正的痛点

### 8.4 最终评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 代码品味 | 2/10 | 数据结构混乱，特殊情况太多 |
| 复杂度 | 1/10 | 9 层调用栈，过度设计 |
| 可维护性 | 3/10 | 调试困难，配置分散 |
| 性能 | 4/10 | 递归执行，动态创建 MappedStatement |
| 实用性 | 3/10 | 使用率低，没有解决真正的痛点 |
| **总分** | **2.6/10** | **不推荐使用** |

### 8.5 Linus 的建议

**如果是我，我会这么做：**

#### 方案 1：简单场景 - 直接用 MyBatis Plus

```java
@Service
public class CityService {
    @Autowired
    private CityMapper cityMapper;
    
    public Page<City> query(CityQueryRequest request) {
        LambdaQueryWrapper<City> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(City::getOemCode, request.getOemCode())
               .like(StringUtils.isNotEmpty(request.getCityName()), 
                     City::getCityName, request.getCityName());
        
        return cityMapper.selectPage(
            new Page<>(request.getPageIndex(), request.getPageSize()), 
            wrapper
        );
    }
}
```

**优点**：
- 3 行代码解决问题
- 类型安全
- IDE 支持重构
- 性能好

#### 方案 2：复杂场景 - 策略模式 + 配置文件

```java
// 定义查询策略接口
public interface QueryStrategy {
    List<City> query(CityQueryRequest request);
}

// 标准查询策略
public class StandardQueryStrategy implements QueryStrategy {
    public List<City> query(CityQueryRequest request) {
        return cityMapper.selectList(...);
    }
}

// 客制化查询策略
public class CustomQueryStrategy implements QueryStrategy {
    public List<City> query(CityQueryRequest request) {
        // 客制化逻辑
    }
}

// 配置文件（YAML）
query:
  strategies:
    oem001: StandardQueryStrategy
    oem002: CustomQueryStrategy

// 服务层
@Service
public class CityService {
    @Autowired
    private Map<String, QueryStrategy> strategies;
    
    public List<City> query(CityQueryRequest request) {
        String oemCode = request.getOemCode();
        QueryStrategy strategy = strategies.get(oemCode);
        return strategy.query(request);
    }
}
```

**优点**：
- 类型安全
- 易于测试
- 易于扩展
- 配置清晰

#### 方案 3：真正需要动态 SQL - 用 MyBatis Dynamic SQL

```java
// 使用 MyBatis Dynamic SQL（官方支持）
public List<City> query(CityQueryRequest request) {
    return mapper.select(c -> c
        .where(cityOemCode, isEqualTo(request.getOemCode()))
        .and(cityName, isLike(request.getCityName()).when(StringUtils::isNotEmpty))
        .orderBy(cityId)
        .limit(request.getPageSize())
        .offset(request.getPageIndex() * request.getPageSize())
    );
}
```

**优点**：
- 类型安全
- 官方支持
- 性能好
- 可读性强

---

## 九、总结

### 9.1 核心问题

FireFlow 引擎的核心问题是：**用复杂的方式解决了一个简单的问题**。

- 它试图让业务逻辑可配置化，但代价是引入了巨大的复杂度
- 它试图提高灵活性，但牺牲了类型安全和可维护性
- 它试图减少代码量，但实际上增加了理解成本

### 9.2 适用场景

**唯一推荐使用的场景**：
- 你有 100+ 个租户
- 每个租户的业务逻辑差异巨大
- 你有专门的团队维护配置
- 你有完善的可视化配置界面

**对于普通项目**：
- 不要用这个引擎
- 用 MyBatis Plus + 策略模式足够了

### 9.3 最后的话

> "Complexity is the enemy. Any fool can make something complicated. It is hard to make something simple."  
> — Richard Branson

这个引擎是一个典型的**过度设计**案例。它展示了很多"高级"技术：
- 动态代理
- SpEL 表达式
- 责任链模式
- 动态 SQL

但这些技术的组合并没有让系统变得更好，反而让它变得更糟。

**记住**：好的代码应该是简单的、直接的、易于理解的。如果你需要写一份 50 页的文档来解释你的代码，那说明你的代码有问题。

---

**文档版本**：v1.0  
**最后更新**：2025-11-12  
**作者**：Linus Torvalds (AI 模拟)

