# MySQL核心知识点深度解析

> 基于《MySQL实战45讲》（丁奇）+ 大厂高频面试考点整理
> 
> 从基础到进阶，全面掌握MySQL底层原理

---

## 目录

- [第一部分：MySQL基础架构](#第一部分mysql基础架构)
- [第二部分：存储引擎详解](#第二部分存储引擎详解)
- [第三部分：索引原理与优化](#第三部分索引原理与优化)
- [第四部分：事务与隔离级别](#第四部分事务与隔离级别)
- [第五部分：锁机制深度剖析](#第五部分锁机制深度剖析)
- [第六部分：日志系统](#第六部分日志系统)
- [第七部分：主从复制与高可用](#第七部分主从复制与高可用)
- [第八部分：性能优化实战](#第八部分性能优化实战)
- [第九部分：大厂高频面试题](#第九部分大厂高频面试题)

---

## 第一部分：MySQL基础架构

### 1.1 MySQL整体架构图

MySQL采用经典的**分层架构设计**，主要分为三层：

```
+---------------------------+
|      客户端层             |
|   (连接器、查询缓存)       |
+---------------------------+
|      Server层             |
| (分析器、优化器、执行器)   |
+---------------------------+
|     存储引擎层            |
|  (InnoDB、MyISAM等)       |
+---------------------------+
|       文件系统层          |
+---------------------------+
```

### 1.2 一条SQL语句的执行流程

#### 1.2.1 查询语句的执行流程

以查询语句 `SELECT * FROM users WHERE id = 1` 为例：

**步骤1：连接器（Connector）**
- 负责与客户端建立连接、获取权限、维持和管理连接
- 验证用户名和密码
- 查询用户的权限信息并缓存
- 连接分为长连接和短连接
  - **长连接**：连接成功后，客户端持续使用同一个连接
  - **短连接**：每次查询完就断开，下次查询重新建立

⚠️ **注意事项**：
- 长连接累积可能导致内存占用过大（MySQL占用的内存在连接对象里）
- MySQL 5.7+可以通过 `mysql_reset_connection` 重新初始化连接资源
- 定期断开长连接，或者程序里判断执行过大查询后断开连接

**步骤2：查询缓存（Query Cache）**
- MySQL会将查询语句和结果以key-value形式缓存
- 命中缓存则直接返回结果
- ⚠️ **MySQL 8.0已移除查询缓存功能**

**为什么移除查询缓存？**
- 只要表有更新，这个表上的所有查询缓存都会被清空
- 对于更新频繁的表，查询缓存命中率很低
- 查询缓存的失效非常频繁

**步骤3：分析器（Analyzer）**
- **词法分析**：识别SQL语句中的关键字、表名、列名等
- **语法分析**：判断SQL语句是否满足MySQL语法
- 如果语法错误，会提示 "You have an error in your SQL syntax"

**步骤4：优化器（Optimizer）**
- 决定使用哪个索引
- 决定表的连接顺序（多表join时）
- 生成执行计划

示例：
```sql
-- 表t有索引a和索引b
SELECT * FROM t WHERE a = 1 AND b = 2;
```
优化器会决定：
- 使用索引a还是索引b？
- 使用索引后是否需要回表？
- 是否使用覆盖索引？

**步骤5：执行器（Executor）**
- 检查用户是否有执行权限
- 打开表，根据表的引擎定义，调用存储引擎接口
- 存储引擎返回数据行
- 执行器判断是否满足条件，满足则加入结果集
- 重复以上步骤直到取完数据

#### 1.2.2 更新语句的执行流程

以更新语句 `UPDATE users SET age = 20 WHERE id = 1` 为例：

1. 执行器找到存储引擎中的这一行
2. 如果数据页在内存（Buffer Pool）中，直接返回；否则从磁盘读入内存
3. 执行器拿到数据后进行更新，调用存储引擎接口写入新数据
4. 存储引擎将新数据更新到内存，同时记录redo log（处于prepare状态）
5. 执行器生成binlog，并写入磁盘
6. 执行器调用存储引擎的提交事务接口，将redo log改为commit状态
7. 更新完成

### 1.3 关键组件详解

#### 1.3.1 连接器

**查看连接状态：**
```sql
SHOW PROCESSLIST;
```

**连接参数设置：**
```ini
# 最大连接数
max_connections = 151

# 交互式连接超时时间（默认8小时）
interactive_timeout = 28800

# 非交互式连接超时时间
wait_timeout = 28800
```

#### 1.3.2 分析器与优化器

优化器的主要优化策略：
1. **重写查询**：简化查询，如常量传播
2. **选择索引**：根据统计信息选择最优索引
3. **表连接顺序**：确定多表join的顺序
4. **索引下推**：将部分条件下推到存储引擎层

---

## 第二部分：存储引擎详解

### 2.1 存储引擎对比

| 特性 | InnoDB | MyISAM | Memory |
|------|--------|--------|--------|
| 事务支持 | ✅ 支持 | ❌ 不支持 | ❌ 不支持 |
| 行级锁 | ✅ 支持 | ❌ 表锁 | ❌ 表锁 |
| 外键 | ✅ 支持 | ❌ 不支持 | ❌ 不支持 |
| MVCC | ✅ 支持 | ❌ 不支持 | ❌ 不支持 |
| 崩溃恢复 | ✅ 支持 | ❌ 不支持 | ❌ 不支持 |
| 索引类型 | B+树 | B+树 | Hash/B+树 |
| 全文索引 | ✅ 5.6+ | ✅ 支持 | ❌ 不支持 |
| 数据缓存 | ✅ Buffer Pool | ❌ 只缓存索引 | ✅ 内存中 |

**推荐使用InnoDB的理由：**
1. 支持事务，适合OLTP场景
2. 行级锁，并发性能好
3. 崩溃恢复能力强（crash-safe）
4. 从MySQL 5.5开始成为默认引擎

### 2.2 InnoDB存储结构

#### 2.2.1 表空间（Tablespace）

InnoDB的所有数据逻辑存储在表空间中：

```
系统表空间 (ibdata1)
  └─ 数据字典
  └─ undo日志
  └─ doublewrite buffer
  └─ change buffer

独立表空间 (.ibd文件)
  └─ 表数据
  └─ 索引数据
```

**配置独立表空间：**
```ini
innodb_file_per_table = ON  # 默认开启
```

#### 2.2.2 页（Page）结构

InnoDB以**页（Page）**为单位管理磁盘和内存，默认页大小为**16KB**。

**页的类型：**
- 数据页（B+树节点）
- undo页
- 系统页
- 事务数据页
- 插入缓冲位图页
- ...

**页的基本结构：**
```
+-----------------------+
| File Header (38字节)   | 页的通用信息
+-----------------------+
| Page Header (56字节)   | 数据页专用信息
+-----------------------+
| Infimum + Supremum     | 虚拟的最小最大记录
+-----------------------+
| User Records           | 用户记录
+-----------------------+
| Free Space             | 空闲空间
+-----------------------+
| Page Directory         | 页目录（稀疏索引）
+-----------------------+
| File Trailer (8字节)   | 校验和
+-----------------------+
```

#### 2.2.3 行格式（Row Format）

InnoDB支持4种行格式：

**1. COMPACT（紧凑格式）**
```
+-------------+----------+----------+------+------+
| 变长字段长度 | NULL标志位 | 记录头信息 | 列1 | 列2 |
+-------------+----------+----------+------+------+
```

**2. REDUNDANT（冗余格式）**
- 5.0之前的格式，已不推荐使用

**3. DYNAMIC（动态格式，MySQL 5.7默认）**
- 处理行溢出更高效
- 超过768字节的列，只在数据页存储20字节指针，实际数据存在溢出页

**4. COMPRESSED（压缩格式）**
- 在DYNAMIC基础上增加压缩

**设置行格式：**
```sql
CREATE TABLE t1 (
    id INT,
    name VARCHAR(100)
) ROW_FORMAT=DYNAMIC;
```

### 2.3 InnoDB内存结构

#### 2.3.1 Buffer Pool（缓冲池）

**核心作用：**
- 缓存表数据和索引数据
- 把磁盘上的数据加载到缓冲池，读写在内存中进行
- 以页为单位缓存数据

**配置：**
```ini
# Buffer Pool大小，建议设置为物理内存的50%-80%
innodb_buffer_pool_size = 1G

# Buffer Pool实例数量，减少并发争用
innodb_buffer_pool_instances = 8
```

**Buffer Pool的管理算法：**
- 使用改进的**LRU算法**（分为young区和old区）
- 新读取的页插入到LRU链表的5/8处（old区头部）
- 在old区停留超过1秒且被访问，才移到young区
- 避免全表扫描污染Buffer Pool

**查看Buffer Pool状态：**
```sql
SHOW ENGINE INNODB STATUS;
```

#### 2.3.2 Change Buffer（写缓冲）

**作用：**
- 针对**非唯一辅助索引**的更新操作
- 如果数据页不在Buffer Pool中，先将更新操作缓存在Change Buffer
- 后续读取数据页时进行merge操作
- 减少磁盘随机IO

**适用场景：**
- 写多读少的业务
- 非唯一索引的更新

**不适用场景：**
- 唯一索引（需要判断唯一性，必须读数据页）
- 读多写少的业务

**配置：**
```ini
# Change Buffer占Buffer Pool的比例
innodb_change_buffer_max_size = 25  # 默认25%

# Change Buffer的类型
innodb_change_buffering = all  # all, none, inserts, deletes, changes, purges
```

#### 2.3.3 Adaptive Hash Index（自适应哈希索引）

**特点：**
- InnoDB自动优化功能
- 对于热点页的查询，自动建立哈希索引
- 可以将B+树的查询从O(log n)优化到O(1)

**配置：**
```ini
innodb_adaptive_hash_index = ON
```

#### 2.3.4 Log Buffer（日志缓冲）

**作用：**
- 缓存redo log，然后定期刷到磁盘
- 减少磁盘IO

**配置：**
```ini
innodb_log_buffer_size = 16M
```

---

## 第三部分：索引原理与优化

### 3.1 索引的本质

索引是一种**数据结构**，目的是帮助MySQL**高效获取数据**。

**没有索引：** 需要全表扫描，时间复杂度O(n)  
**有了索引：** 类似二分查找，时间复杂度O(log n)

### 3.2 为什么使用B+树？

#### 3.2.1 常见数据结构对比

**1. 哈希表**
- ✅ 优点：等值查询快，O(1)
- ❌ 缺点：不支持范围查询、不支持排序

**2. 二叉搜索树（BST）**
- ❌ 缺点：可能退化为链表，极端情况O(n)

**3. AVL树/红黑树**
- ✅ 优点：保持平衡，查询稳定O(log n)
- ❌ 缺点：树高较大，IO次数多

示例：100万条数据
- AVL树高度约为 log₂(1000000) ≈ 20
- B+树（1000叉）高度约为 log₁₀₀₀(1000000) = 2

**4. B树**
- ✅ 优点：多路平衡查找树，树高低
- ❌ 缺点：非叶子节点存数据，存储的key数量少；范围查询需要回溯

**5. B+树 ✅（InnoDB的选择）**
- ✅ 非叶子节点只存key，不存数据，可以存更多key
- ✅ 所有数据都存在叶子节点
- ✅ 叶子节点之间有双向指针，范围查询效率高
- ✅ 树高低，IO次数少

#### 3.2.2 B+树的详细结构

**特点：**
- 每个节点对应一个页（16KB）
- 叶子节点存储完整的数据记录（聚簇索引）或主键值（辅助索引）
- 非叶子节点存储索引项（key + 指针）

**为什么B+树的高度一般为2-4层？**

假设：
- 每个页16KB
- 主键bigint（8字节）
- 指针6字节
- 每条记录1KB

计算：
- 非叶子节点：16KB / (8B + 6B) ≈ 1170个key
- 叶子节点：16KB / 1KB = 16条记录

- **2层B+树**：1170 × 16 = 18,720条记录
- **3层B+树**：1170 × 1170 × 16 ≈ 2200万条记录

⭐ **结论：** 3层B+树可以存储2000多万条记录，且只需3次IO！

### 3.3 索引类型

#### 3.3.1 聚簇索引（Clustered Index）

**定义：** 数据行的物理顺序与键值的逻辑顺序相同，一个表只能有一个聚簇索引。

**InnoDB中的聚簇索引：**
- 主键索引就是聚簇索引
- 叶子节点存储整行数据
- 如果没有定义主键，InnoDB会选择唯一非空索引
- 如果没有唯一非空索引，InnoDB会创建隐藏的row_id作为聚簇索引

**优点：**
- 范围查询效率高（叶子节点有序且连续）
- 查询快（叶子节点包含全部数据）

**缺点：**
- 插入速度依赖插入顺序（非顺序插入可能导致页分裂）
- 更新主键代价高
- 二级索引需要两次查找（先查二级索引，再回表查聚簇索引）

#### 3.3.2 辅助索引（Secondary Index）

**定义：** 也叫二级索引，叶子节点存储的是**主键值**。

**查询流程：**
1. 在辅助索引的B+树上查找，找到主键值
2. 拿主键值去聚簇索引上查找（**回表**）
3. 在聚簇索引上找到完整的数据行

**示例：**
```sql
CREATE TABLE users (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    age INT,
    KEY idx_name (name)
);

SELECT * FROM users WHERE name = 'Tom';
```

查询过程：
1. 在`idx_name`索引上找到name='Tom'的记录，得到id=10
2. 拿id=10去主键索引上查找（回表）
3. 返回完整记录

#### 3.3.3 覆盖索引（Covering Index）

**定义：** 查询的列都在索引中，不需要回表。

**示例：**
```sql
-- 索引：KEY idx_name (name)

-- 需要回表
SELECT * FROM users WHERE name = 'Tom';

-- 不需要回表（覆盖索引）
SELECT id FROM users WHERE name = 'Tom';
SELECT name FROM users WHERE name = 'Tom';
SELECT id, name FROM users WHERE name = 'Tom';
```

**优点：**
- 减少IO，提升性能
- 可以减少回表的次数

**EXPLAIN中的体现：**
```
Extra: Using index
```

#### 3.3.4 联合索引（Composite Index）

**定义：** 在多个列上建立的索引。

**最左前缀原则：**
```sql
-- 创建联合索引
KEY idx_abc (a, b, c)

-- 可以使用索引的查询
WHERE a = 1
WHERE a = 1 AND b = 2
WHERE a = 1 AND b = 2 AND c = 3
WHERE a = 1 AND c = 3  -- 只用到a

-- 不能使用索引的查询
WHERE b = 2
WHERE c = 3
WHERE b = 2 AND c = 3
```

**索引的底层存储顺序：**
- 先按a排序
- a相同，按b排序
- b相同，按c排序

**示例数据：**
```
(1, 2, 3)
(1, 2, 4)
(1, 3, 1)
(2, 1, 5)
```

### 3.4 索引优化实战

#### 3.4.1 索引设计原则

1. **选择区分度高的列**
   ```sql
   -- 区分度计算
   SELECT COUNT(DISTINCT col) / COUNT(*) AS selectivity FROM table;
   ```
   区分度越高，索引效果越好。

2. **索引列不要参与计算**
   ```sql
   -- ❌ 错误：索引失效
   SELECT * FROM users WHERE id + 1 = 10;
   
   -- ✅ 正确
   SELECT * FROM users WHERE id = 9;
   ```

3. **字符串索引要加引号**
   ```sql
   -- ❌ 错误：发生隐式类型转换，索引失效
   SELECT * FROM users WHERE phone = 13800138000;
   
   -- ✅ 正确
   SELECT * FROM users WHERE phone = '13800138000';
   ```

4. **尽量使用前缀索引**
   ```sql
   -- 对于长字符串，使用前缀索引
   CREATE INDEX idx_email ON users(email(10));
   ```

5. **避免使用SELECT ***
   - 可能用不到覆盖索引
   - 传输的数据量大

6. **使用联合索引而非多个单列索引**
   ```sql
   -- ❌ 不推荐
   KEY idx_a (a)
   KEY idx_b (b)
   
   -- ✅ 推荐
   KEY idx_ab (a, b)
   ```

#### 3.4.2 索引失效的场景

1. **使用!=、<>、NOT IN**
   ```sql
   SELECT * FROM users WHERE age != 20;
   ```

2. **LIKE以%开头**
   ```sql
   -- ❌ 索引失效
   SELECT * FROM users WHERE name LIKE '%Tom';
   
   -- ✅ 索引有效
   SELECT * FROM users WHERE name LIKE 'Tom%';
   ```

3. **OR连接**
   ```sql
   -- 如果OR前后有一个列没有索引，整个查询都不会使用索引
   SELECT * FROM users WHERE id = 1 OR age = 20;
   ```

4. **隐式类型转换**
   ```sql
   -- phone是VARCHAR类型
   SELECT * FROM users WHERE phone = 13800138000;  -- 索引失效
   ```

5. **对索引列使用函数**
   ```sql
   SELECT * FROM users WHERE UPPER(name) = 'TOM';  -- 索引失效
   ```

#### 3.4.3 索引下推（Index Condition Pushdown, ICP）

**MySQL 5.6+的优化特性**

**示例：**
```sql
CREATE INDEX idx_name_age ON users(name, age);

SELECT * FROM users WHERE name LIKE 'Tom%' AND age = 20;
```

**没有索引下推：**
1. 根据name='Tom%'从索引中取出所有记录
2. 回表获取完整数据
3. 在Server层过滤age=20

**有了索引下推：**
1. 根据name='Tom%'从索引中取出记录
2. 在索引中过滤age=20（不需要回表）
3. 只对符合条件的记录回表

**EXPLAIN中的体现：**
```
Extra: Using index condition
```

#### 3.4.4 页分裂与页合并

**页分裂（Page Split）**

发生场景：插入数据时，页已满，需要分裂。

**示例：**
```
原始页: [1, 3, 5, 7, 9, 11, 13, 15]  (已满)

插入10:
页1: [1, 3, 5, 7, 9]
页2: [10, 11, 13, 15]
```

**影响：**
- 页的利用率降低（只有50%）
- 性能下降（需要移动数据、更新索引）

**如何避免：**
- 使用自增主键（顺序插入）
- 避免使用UUID作为主键（随机插入）

**页合并（Page Merge）**

发生场景：删除数据后，页的利用率低于50%（MERGE_THRESHOLD），与相邻页合并。

**配置：**
```sql
-- 设置合并阈值
CREATE TABLE t (
    id INT PRIMARY KEY
) COMMENT='MERGE_THRESHOLD=40';
```

### 3.5 EXPLAIN详解

使用EXPLAIN分析SQL的执行计划。

```sql
EXPLAIN SELECT * FROM users WHERE name = 'Tom';
```

**输出字段说明：**

| 字段 | 说明 |
|------|------|
| id | 查询序号 |
| select_type | 查询类型（SIMPLE, PRIMARY, SUBQUERY等） |
| table | 访问的表 |
| **type** | 访问类型（性能从好到坏）|
| possible_keys | 可能使用的索引 |
| **key** | 实际使用的索引 |
| key_len | 使用索引的长度 |
| ref | 与索引比较的列 |
| **rows** | 预计扫描的行数 |
| filtered | 过滤后的行数百分比 |
| **Extra** | 额外信息 |

#### 3.5.1 type字段（重要）

**从好到坏排序：**

1. **system**：表只有一行记录（系统表）
2. **const**：通过主键或唯一索引查询，最多返回一行
   ```sql
   SELECT * FROM users WHERE id = 1;
   ```

3. **eq_ref**：唯一索引扫描，常见于多表join
   ```sql
   SELECT * FROM t1 JOIN t2 ON t1.id = t2.id;
   ```

4. **ref**：非唯一索引扫描
   ```sql
   SELECT * FROM users WHERE name = 'Tom';
   ```

5. **range**：范围扫描（>, <, BETWEEN, IN）
   ```sql
   SELECT * FROM users WHERE id > 10 AND id < 20;
   ```

6. **index**：全索引扫描
   ```sql
   SELECT id FROM users;  -- 覆盖索引
   ```

7. **ALL**：全表扫描 ❌
   ```sql
   SELECT * FROM users;
   ```

⭐ **优化目标：** 至少达到range级别，最好是ref级别。

#### 3.5.2 Extra字段（重要）

- **Using index**：使用覆盖索引，不需要回表 ✅
- **Using where**：在Server层过滤数据
- **Using index condition**：使用索引下推 ✅
- **Using temporary**：使用临时表，常见于ORDER BY和GROUP BY ⚠️
- **Using filesort**：使用外部排序，性能差 ❌
- **Using join buffer**：使用连接缓冲 ⚠️

---

## 第四部分：事务与隔离级别

### 4.1 事务的ACID特性

- **A (Atomicity) 原子性**：事务中的操作要么全部成功,要么全部失败
- **C (Consistency) 一致性**：事务前后数据的完整性保持一致
- **I (Isolation) 隔离性**：多个事务并发执行时互不干扰
- **D (Durability) 持久性**：事务提交后,对数据的修改是永久的

### 4.2 并发事务的问题

#### 4.2.1 脏读（Dirty Read）

事务A读取了事务B**未提交**的数据，事务B回滚后，A读到的是脏数据。

```
时间  事务A                    事务B
t1                          UPDATE account SET balance = 500 WHERE id = 1;
t2   SELECT balance FROM account WHERE id = 1;  -- 读到500（脏数据）
t3                          ROLLBACK;
t4   -- balance实际还是1000
```

#### 4.2.2 不可重复读（Non-Repeatable Read）

事务A两次读取同一数据，结果不一致（事务B在中间**修改并提交**了数据）。

```
时间  事务A                    事务B
t1   SELECT balance FROM account WHERE id = 1;  -- 读到1000
t2                          UPDATE account SET balance = 500 WHERE id = 1;
t3                          COMMIT;
t4   SELECT balance FROM account WHERE id = 1;  -- 读到500
```

#### 4.2.3 幻读（Phantom Read）

事务A两次查询，结果集不一致（事务B在中间**插入或删除并提交**了数据）。

```
时间  事务A                    事务B
t1   SELECT * FROM account WHERE balance > 500;  -- 10条记录
t2                          INSERT INTO account VALUES (11, 600);
t3                          COMMIT;
t4   SELECT * FROM account WHERE balance > 500;  -- 11条记录
```

### 4.3 事务隔离级别

| 隔离级别 | 脏读 | 不可重复读 | 幻读 |
|---------|------|-----------|------|
| **读未提交（Read Uncommitted）** | ✅ | ✅ | ✅ |
| **读已提交（Read Committed）** | ❌ | ✅ | ✅ |
| **可重复读（Repeatable Read）** | ❌ | ❌ | ❌ |
| **串行化（Serializable）** | ❌ | ❌ | ❌ |

**InnoDB默认隔离级别：可重复读（Repeatable Read）**

**查看和设置隔离级别：**
```sql
-- 查看当前隔离级别
SELECT @@transaction_isolation;

-- 设置隔离级别
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

### 4.4 MVCC（多版本并发控制）

**MVCC的核心思想：** 读不加锁，读写不冲突，提高并发性能。

#### 4.4.1 版本链

InnoDB为每行记录添加了三个隐藏列：

| 隐藏列 | 说明 |
|--------|------|
| **DB_TRX_ID** | 最后修改该行的事务ID（6字节） |
| **DB_ROLL_PTR** | 回滚指针，指向undo log中的前一个版本（7字节） |
| **DB_ROW_ID** | 行ID，如果没有主键则自动生成（6字节） |

**示例：**
```sql
-- 初始数据
id=1, name='Tom', age=20, DB_TRX_ID=100

-- 事务101更新
UPDATE users SET age=21 WHERE id=1;
-- 新版本: id=1, name='Tom', age=21, DB_TRX_ID=101, DB_ROLL_PTR -> undo log
-- undo log: id=1, name='Tom', age=20, DB_TRX_ID=100

-- 事务102更新
UPDATE users SET age=22 WHERE id=1;
-- 新版本: id=1, name='Tom', age=22, DB_TRX_ID=102, DB_ROLL_PTR -> undo log
-- undo log链: age=21(101) -> age=20(100)
```

版本链：
```
当前版本(age=22, trx_id=102)
    ↓
undo log(age=21, trx_id=101)
    ↓
undo log(age=20, trx_id=100)
```

#### 4.4.2 ReadView（读视图）

**ReadView是什么？**
- 事务在执行快照读（SELECT）时生成的读视图
- 用于判断哪些版本对当前事务可见

**ReadView包含的核心字段：**
- **m_ids**：当前活跃的事务ID列表（未提交的事务）
- **min_trx_id**：m_ids中的最小值
- **max_trx_id**：下一个要分配的事务ID（当前最大事务ID+1）
- **creator_trx_id**：当前事务的ID

**可见性判断规则：**

```python
# 假设要访问的记录的事务ID为 trx_id

if trx_id < min_trx_id:
    # 说明该版本在当前事务开启之前就已经提交了
    return 可见

elif trx_id >= max_trx_id:
    # 说明该版本是在当前事务开启之后才开启的
    return 不可见

elif trx_id in m_ids:
    # 说明该版本是由还未提交的事务生成的
    return 不可见

else:
    # 说明该版本是由已经提交的事务生成的
    return 可见
```

#### 4.4.3 RC和RR的区别

**Read Committed（读已提交）：**
- 每次SELECT都生成一个新的ReadView
- 可以读到其他事务已提交的数据

**Repeatable Read（可重复读）：**
- 第一次SELECT时生成ReadView，之后复用
- 保证多次读取结果一致

**示例：**

```sql
-- 初始数据: id=1, age=20

-- 事务A（trx_id=100）
BEGIN;
SELECT age FROM users WHERE id=1;  -- 读到20

-- 事务B（trx_id=101）
BEGIN;
UPDATE users SET age=21 WHERE id=1;
COMMIT;

-- 事务A继续
SELECT age FROM users WHERE id=1;
-- RC：读到21（每次生成新的ReadView）
-- RR：读到20（复用第一次的ReadView）
```

#### 4.4.4 幻读问题

**InnoDB的可重复读级别真的解决了幻读吗？**

**快照读：** 通过MVCC解决了幻读
```sql
SELECT * FROM users WHERE age > 20;  -- 快照读
```

**当前读：** 没有完全解决幻读，需要使用锁
```sql
SELECT * FROM users WHERE age > 20 FOR UPDATE;  -- 当前读
SELECT * FROM users WHERE age > 20 LOCK IN SHARE MODE;
INSERT / UPDATE / DELETE  -- 当前读
```

**InnoDB使用Next-Key Lock解决幻读：**
- Record Lock（行锁）+ Gap Lock（间隙锁）
- 锁住记录和记录之间的间隙，防止其他事务插入

---

## 第五部分：锁机制深度剖析

### 5.1 锁的分类

#### 5.1.1 按锁的粒度分类

**1. 全局锁（Global Lock）**

**作用：** 锁定整个数据库实例。

**使用场景：** 全库逻辑备份。

```sql
-- 加全局读锁
FLUSH TABLES WITH READ LOCK;

-- 执行备份
mysqldump -uroot -p database > backup.sql

-- 释放锁
UNLOCK TABLES;
```

**缺点：**
- 整个数据库处于只读状态
- 对业务影响大

**更好的方案（InnoDB）：**
```bash
# 使用mysqldump的--single-transaction参数
# 利用MVCC获得一致性视图，不需要加锁
mysqldump --single-transaction -uroot -p database > backup.sql
```

**2. 表级锁（Table Lock）**

**表锁：**
```sql
-- 加表读锁
LOCK TABLES users READ;

-- 加表写锁
LOCK TABLES users WRITE;

-- 释放锁
UNLOCK TABLES;
```

**元数据锁（MDL，Metadata Lock）：**
- MySQL 5.5引入
- 自动加锁，无需显式声明
- 保证表结构变更的安全性

```sql
-- 事务A
BEGIN;
SELECT * FROM users;  -- 自动加MDL读锁

-- 事务B
ALTER TABLE users ADD COLUMN email VARCHAR(100);  -- 等待MDL写锁
```

⚠️ **MDL锁的风险：**
- 长事务持有MDL读锁
- 后续的DDL操作被阻塞
- 大量请求被阻塞，数据库hang住

**解决方案：**
- 避免长事务
- 在业务低峰期执行DDL
- 使用pt-online-schema-change等工具

**3. 行级锁（Row Lock）**

InnoDB支持行级锁，粒度最小，并发性能最好。

#### 5.1.2 按锁的模式分类

**1. 共享锁（Shared Lock，S锁）**
- 也叫读锁
- 多个事务可以同时持有S锁
- S锁与S锁兼容，与X锁互斥

```sql
SELECT * FROM users WHERE id=1 LOCK IN SHARE MODE;
-- MySQL 8.0+
SELECT * FROM users WHERE id=1 FOR SHARE;
```

**2. 排他锁（Exclusive Lock，X锁）**
- 也叫写锁
- 只有一个事务可以持有X锁
- X锁与S锁、X锁都互斥

```sql
SELECT * FROM users WHERE id=1 FOR UPDATE;
UPDATE / DELETE / INSERT  -- 自动加X锁
```

**锁兼容性矩阵：**

|      | S锁 | X锁 |
|------|-----|-----|
| S锁  | ✅  | ❌  |
| X锁  | ❌  | ❌  |

#### 5.1.3 InnoDB行锁的算法

**1. Record Lock（记录锁）**

锁定单个行记录。

```sql
-- id是主键或唯一索引
SELECT * FROM users WHERE id=1 FOR UPDATE;
-- 只锁定id=1这一行
```

**2. Gap Lock（间隙锁）**

锁定索引记录之间的间隙，防止其他事务插入。

```sql
-- 假设id有值: 1, 5, 10

SELECT * FROM users WHERE id=5 FOR UPDATE;
-- 锁定间隙: (1, 5) 和 (5, 10)
-- 防止插入id=2,3,4,6,7,8,9
```

**3. Next-Key Lock（临键锁）**

Record Lock + Gap Lock，锁定记录和前面的间隙。

```sql
-- 假设age有索引，值为: 10, 20, 30

SELECT * FROM users WHERE age >= 20 FOR UPDATE;
-- 锁定: (10, 20], (20, 30], (30, +∞)
```

⭐ **InnoDB默认使用Next-Key Lock，防止幻读。**

### 5.2 死锁

#### 5.2.1 死锁产生的条件

1. 互斥条件
2. 请求与保持条件
3. 不剥夺条件
4. 循环等待条件

#### 5.2.2 死锁示例

```sql
-- 事务A
BEGIN;
UPDATE users SET age=20 WHERE id=1;  -- 锁定id=1
-- 等待1秒
UPDATE users SET age=20 WHERE id=2;  -- 等待id=2的锁

-- 事务B
BEGIN;
UPDATE users SET age=30 WHERE id=2;  -- 锁定id=2
-- 等待1秒
UPDATE users SET age=30 WHERE id=1;  -- 等待id=1的锁（死锁！）
```

**MySQL检测到死锁后：**
- 自动回滚其中一个事务（代价较小的）
- 返回错误：`Deadlock found when trying to get lock`

#### 5.2.3 如何避免死锁

1. **按相同顺序访问资源**
   ```sql
   -- 都按照id从小到大的顺序访问
   UPDATE users SET age=20 WHERE id=1;
   UPDATE users SET age=20 WHERE id=2;
   ```

2. **尽量使用主键索引**
   - 减少锁的范围
   - 避免间隙锁

3. **控制事务大小**
   - 拆分大事务
   - 减少锁持有时间

4. **降低隔离级别**
   - 如果业务允许，使用RC隔离级别（没有间隙锁）

5. **添加合理的索引**
   - 避免全表扫描
   - 减少锁的范围

#### 5.2.4 死锁排查

**查看最近一次死锁日志：**
```sql
SHOW ENGINE INNODB STATUS;
```

输出中查找：
```
------------------------
LATEST DETECTED DEADLOCK
------------------------
```

### 5.3 锁优化实战

#### 5.3.1 锁等待分析

**查看当前锁等待：**
```sql
-- MySQL 8.0+
SELECT * FROM performance_schema.data_locks;
SELECT * FROM performance_schema.data_lock_waits;

-- MySQL 5.7
SELECT * FROM information_schema.innodb_locks;
SELECT * FROM information_schema.innodb_lock_waits;
```

**查看正在执行的事务：**
```sql
SELECT * FROM information_schema.innodb_trx;
```

**杀死长事务：**
```sql
KILL trx_mysql_thread_id;
```

#### 5.3.2 优化建议

1. **尽量使用主键或唯一索引查询**
   - 减少锁的范围
   - 只锁定需要的行

2. **避免大事务**
   - 拆分成小事务
   - 减少锁持有时间

3. **使用覆盖索引**
   - 减少回表
   - 提升性能

4. **批量操作分批进行**
   ```sql
   -- ❌ 一次删除100万行
   DELETE FROM users WHERE status = 0;
   
   -- ✅ 分批删除
   DELETE FROM users WHERE status = 0 LIMIT 1000;
   ```

5. **合理使用锁模式**
   - 读操作使用LOCK IN SHARE MODE（如果需要加锁）
   - 写操作使用FOR UPDATE

---

## 第六部分：日志系统

### 6.1 redo log（重做日志）

#### 6.1.1 为什么需要redo log？

**问题：** 如果每次更新都直接写磁盘，性能太差（随机IO）。

**解决方案：** WAL（Write-Ahead Logging）技术
- 先写日志（顺序IO），再写磁盘
- 日志记录了"在某个数据页上做了什么修改"

#### 6.1.2 redo log的特点

1. **InnoDB特有的日志**
2. **物理日志**：记录"在某个数据页上做了什么修改"
3. **循环写**：固定大小，写满后从头开始覆盖
4. **crash-safe**：保证数据不丢失

#### 6.1.3 redo log的结构

```
+---------------------------------------+
| ib_logfile0 (1GB)                     |
+---------------------------------------+
| ib_logfile1 (1GB)                     |
+---------------------------------------+
| ib_logfile2 (1GB)                     |
+---------------------------------------+
```

**写入流程：**
```
write pos：当前写入位置
checkpoint：当前擦除位置

+-----------------+-----------------+
|   已写入未刷盘   |   可以写入      |
+-----------------+-----------------+
                 ↑                 ↑
           checkpoint          write pos
```

**配置：**
```ini
# redo log文件大小
innodb_log_file_size = 1G

# redo log文件数量
innodb_log_files_in_group = 3

# redo log刷盘策略
innodb_flush_log_at_trx_commit = 1
```

#### 6.1.4 innodb_flush_log_at_trx_commit参数

| 值 | 说明 | 性能 | 安全性 |
|----|------|------|--------|
| 0 | 每秒刷盘一次 | 高 | 低（MySQL crash丢失1秒数据） |
| 1 | 每次事务提交都刷盘（默认） | 低 | 高（保证不丢数据） |
| 2 | 每次事务提交写入OS缓存，每秒刷盘 | 中 | 中（OS crash丢失数据） |

**推荐配置：**
- 核心业务：1（默认）
- 非核心业务可以设置为2，提升性能

### 6.2 binlog（归档日志）

#### 6.2.1 binlog的特点

1. **Server层的日志**（所有存储引擎都可以使用）
2. **逻辑日志**：记录SQL语句的逻辑
3. **追加写**：不会覆盖，一直追加
4. **用途**：主从复制、数据恢复

#### 6.2.2 binlog的格式

**1. STATEMENT格式**
- 记录SQL语句
- 优点：日志量小
- 缺点：有些函数会导致主从不一致（如NOW(), UUID()）

```sql
UPDATE users SET update_time=NOW() WHERE id=1;
```

**2. ROW格式（推荐）**
- 记录每一行的实际变化
- 优点：保证主从一致
- 缺点：日志量大

```
### UPDATE `test`.`users`
### WHERE
###   @1=1 /* id */
###   @2='Tom' /* name */
### SET
###   @1=1
###   @2='Tom'
###   @3='2025-01-01 12:00:00' /* update_time */
```

**3. MIXED格式**
- 自动选择STATEMENT或ROW
- MySQL自动判断是否会导致不一致

**配置：**
```ini
# binlog格式
binlog_format = ROW

# binlog刷盘策略
sync_binlog = 1
```

#### 6.2.3 sync_binlog参数

| 值 | 说明 | 性能 | 安全性 |
|----|------|------|--------|
| 0 | 由OS控制刷盘 | 高 | 低 |
| 1 | 每次事务提交都刷盘（推荐） | 低 | 高 |
| N | 每N个事务刷盘一次 | 中 | 中 |

### 6.3 undo log（回滚日志）

#### 6.3.1 undo log的作用

1. **事务回滚**
2. **MVCC（多版本并发控制）**

#### 6.3.2 undo log的类型

**1. insert undo log**
- INSERT操作产生
- 事务提交后可以立即删除

**2. update undo log**
- UPDATE和DELETE操作产生
- 需要保留给MVCC使用
- 由purge线程定期清理

### 6.4 两阶段提交

#### 6.4.1 为什么需要两阶段提交？

**问题：** redo log和binlog是两个独立的日志，如何保证一致性？

**场景1：先写redo log，后写binlog**
```
1. 写入redo log（commit状态）
2. MySQL crash（binlog未写入）
3. 恢复后，数据已更新（根据redo log）
4. 但binlog中没有记录，主从不一致！
```

**场景2：先写binlog，后写redo log**
```
1. 写入binlog
2. MySQL crash（redo log未写入）
3. 恢复后，数据未更新（没有redo log）
4. 但binlog中有记录，主从不一致！
```

#### 6.4.2 两阶段提交流程

```
1. InnoDB准备阶段
   - 写入redo log（prepare状态）
   
2. 写入binlog
   
3. InnoDB提交阶段
   - 写入redo log（commit状态）
```

**恢复逻辑：**
- 如果redo log是prepare状态，检查binlog
  - binlog完整：提交事务
  - binlog不完整：回滚事务
- 如果redo log是commit状态：提交事务

⭐ **通过两阶段提交，保证了redo log和binlog的一致性。**

### 6.5 日志相关的面试题

**Q1：为什么MySQL需要两份日志（redo log和binlog）？**

A：历史原因。
- MySQL最初没有InnoDB，自带的MyISAM没有crash-safe能力
- InnoDB作为插件加入MySQL，为了实现crash-safe，引入了redo log
- binlog用于主从复制和数据恢复，是Server层的功能

**Q2：redo log和binlog的区别？**

| 特性 | redo log | binlog |
|------|----------|--------|
| 所属 | InnoDB | Server层 |
| 类型 | 物理日志 | 逻辑日志 |
| 写入方式 | 循环写 | 追加写 |
| 作用 | crash-safe | 主从复制、数据恢复 |

**Q3：如何保证主从一致性？**

A：通过binlog进行主从复制。
- 主库写入binlog
- 从库拉取binlog并执行
- 使用ROW格式保证一致性

**Q4：如果误删了数据，如何恢复？**

A：通过binlog进行数据恢复。
1. 找到全量备份
2. 恢复全量备份
3. 重放binlog（从备份点到误删之前）

```bash
# 恢复全量备份
mysql -uroot -p < backup.sql

# 重放binlog
mysqlbinlog --start-position=1234 --stop-position=5678 binlog.000001 | mysql -uroot -p
```

---

## 第七部分：主从复制与高可用

### 7.1 主从复制原理

#### 7.1.1 复制流程

```
主库（Master）                  从库（Slave）
    |                              |
    | 1. 写入binlog                |
    |----------------------------->|
    |                              | 2. IO线程拉取binlog
    |                              | 3. 写入relay log
    |                              | 4. SQL线程执行relay log
    |<-----------------------------|
```

**详细步骤：**

1. **主库操作**
   - 执行SQL语句
   - 写入binlog

2. **从库IO线程**
   - 连接主库
   - 读取binlog
   - 写入relay log（中继日志）

3. **从库SQL线程**
   - 读取relay log
   - 执行SQL语句
   - 更新数据

#### 7.1.2 复制模式

**1. 异步复制（Async Replication，默认）**
```
主库 --写入binlog--> 返回客户端成功
                     |
                     | (异步)
                     ↓
                  从库拉取
```

**特点：**
- 性能好
- 可能丢失数据（主库crash后，binlog未传输到从库）

**2. 半同步复制（Semi-Sync Replication）**
```
主库 --写入binlog--> 等待至少一个从库ACK --> 返回客户端成功
                     |
                     | (同步)
                     ↓
                  从库接收并写入relay log
```

**特点：**
- 数据安全性更高
- 性能有所下降

**配置：**
```sql
-- 主库安装插件
INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';
SET GLOBAL rpl_semi_sync_master_enabled = 1;

-- 从库安装插件
INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
```

**3. 组复制（Group Replication）**
- MySQL 5.7.17+引入
- 基于Paxos协议
- 多主模式

### 7.2 主从延迟

#### 7.2.1 主从延迟的原因

1. **从库性能差**
   - 从库配置低于主库
   - 从库负载高（承担了大量读请求）

2. **大事务**
   - 主库执行大事务很快（并行）
   - 从库SQL线程单线程执行（串行）

3. **从库并行复制能力不足**
   - MySQL 5.6之前，从库SQL线程是单线程

4. **网络延迟**
   - 主从库之间的网络带宽不足

#### 7.2.2 如何减少主从延迟

1. **使用更高配置的从库**
2. **避免大事务**
   - 拆分大事务
   - 控制事务大小

3. **使用并行复制**
   ```ini
   # MySQL 5.7+
   slave_parallel_type = LOGICAL_CLOCK
   slave_parallel_workers = 4
   ```

4. **升级到MySQL 8.0**
   - 支持WRITESET并行复制
   - 并行能力更强

5. **读写分离时考虑延迟**
   - 对实时性要求高的读请求，从主库读
   - 使用缓存减少读请求

#### 7.2.3 监控主从延迟

```sql
-- 从库执行
SHOW SLAVE STATUS\G

-- 关注以下字段：
Seconds_Behind_Master: 0  -- 延迟秒数
Slave_IO_Running: Yes     -- IO线程状态
Slave_SQL_Running: Yes    -- SQL线程状态
```

### 7.3 高可用架构

#### 7.3.1 主从架构（一主多从）

```
          +--------+
          | Master |
          +--------+
             /  |  \
            /   |   \
           /    |    \
     +-----+ +-----+ +-----+
     |Slave| |Slave| |Slave|
     +-----+ +-----+ +-----+
```

**优点：**
- 读写分离，提升性能
- 数据备份

**缺点：**
- 主库单点故障
- 需要手动切换

#### 7.3.2 主主架构（双主）

```
     +--------+  <------>  +--------+
     |Master1 |            |Master2 |
     +--------+            +--------+
```

**优点：**
- 互为主从，可以快速切换

**缺点：**
- 需要避免主键冲突
- 数据一致性难以保证

**配置：**
```ini
# Master1
auto_increment_offset = 1
auto_increment_increment = 2

# Master2
auto_increment_offset = 2
auto_increment_increment = 2
```

#### 7.3.3 MHA架构

**MHA（Master High Availability）：**
- 自动监控主库状态
- 主库故障时自动切换
- 补齐binlog差异，保证数据一致性

**架构：**
```
     MHA Manager
         |
    +----|----+
    |    |    |
  Master | Slave1 | Slave2
```

#### 7.3.4 MGR架构

**MGR（MySQL Group Replication）：**
- MySQL官方高可用方案
- 基于Paxos协议
- 支持多主模式
- 自动故障检测和切换

---

## 第八部分：性能优化实战

### 8.1 慢查询分析

#### 8.1.1 开启慢查询日志

```ini
# 开启慢查询日志
slow_query_log = ON

# 慢查询阈值（秒）
long_query_time = 2

# 慢查询日志文件
slow_query_log_file = /var/log/mysql/slow.log

# 记录未使用索引的查询
log_queries_not_using_indexes = ON
```

#### 8.1.2 分析慢查询日志

**使用mysqldumpslow：**
```bash
# 返回访问次数最多的10个SQL
mysqldumpslow -s c -t 10 /var/log/mysql/slow.log

# 返回平均执行时间最长的10个SQL
mysqldumpslow -s at -t 10 /var/log/mysql/slow.log

# 返回总执行时间最长的10个SQL
mysqldumpslow -s t -t 10 /var/log/mysql/slow.log
```

**使用pt-query-digest：**
```bash
pt-query-digest /var/log/mysql/slow.log
```

### 8.2 SQL优化技巧

#### 8.2.1 避免SELECT *

```sql
-- ❌ 不推荐
SELECT * FROM users WHERE id=1;

-- ✅ 推荐
SELECT id, name, age FROM users WHERE id=1;
```

**理由：**
- 传输的数据量大
- 无法使用覆盖索引
- 增加网络开销

#### 8.2.2 小表驱动大表

**IN和EXISTS的选择：**

```sql
-- 当B表小于A表时，使用IN
SELECT * FROM A WHERE id IN (SELECT id FROM B);

-- 当A表小于B表时，使用EXISTS
SELECT * FROM A WHERE EXISTS (SELECT 1 FROM B WHERE B.id = A.id);
```

**原理：**
- IN：先执行子查询，得到结果集，然后外层查询
- EXISTS：外层查询循环，每次判断子查询是否有结果

#### 8.2.3 优化JOIN查询

1. **小表驱动大表**
2. **关联字段建立索引**
3. **避免JOIN太多表**（建议不超过3个）

```sql
-- ❌ 不推荐：大表驱动小表
SELECT * FROM big_table 
LEFT JOIN small_table ON big_table.id = small_table.id;

-- ✅ 推荐：小表驱动大表
SELECT * FROM small_table 
LEFT JOIN big_table ON small_table.id = big_table.id;
```

#### 8.2.4 优化分页查询

**深分页问题：**
```sql
-- 慢：需要扫描10010行，然后丢弃前10000行
SELECT * FROM users ORDER BY id LIMIT 10000, 10;
```

**优化方案1：使用子查询**
```sql
SELECT * FROM users 
WHERE id >= (SELECT id FROM users ORDER BY id LIMIT 10000, 1)
LIMIT 10;
```

**优化方案2：记录上次位置**
```sql
-- 第一次查询
SELECT * FROM users ORDER BY id LIMIT 10;  -- 最大id=10

-- 第二次查询
SELECT * FROM users WHERE id > 10 ORDER BY id LIMIT 10;  -- 最大id=20

-- 第三次查询
SELECT * FROM users WHERE id > 20 ORDER BY id LIMIT 10;
```

#### 8.2.5 避免隐式类型转换

```sql
-- phone是VARCHAR类型

-- ❌ 索引失效（隐式转换为数字）
SELECT * FROM users WHERE phone = 13800138000;

-- ✅ 使用索引
SELECT * FROM users WHERE phone = '13800138000';
```

#### 8.2.6 使用UNION ALL替代UNION

```sql
-- ❌ UNION会去重（需要排序）
SELECT id FROM users WHERE age=20
UNION
SELECT id FROM users WHERE age=30;

-- ✅ UNION ALL不去重（性能更好）
SELECT id FROM users WHERE age=20
UNION ALL
SELECT id FROM users WHERE age=30;
```

### 8.3 数据库设计优化

#### 8.3.1 选择合适的字段类型

1. **整数类型**

| 类型 | 字节 | 范围（有符号） |
|------|------|---------------|
| TINYINT | 1 | -128 ~ 127 |
| SMALLINT | 2 | -32768 ~ 32767 |
| MEDIUMINT | 3 | -8388608 ~ 8388607 |
| INT | 4 | -2147483648 ~ 2147483647 |
| BIGINT | 8 | -9223372036854775808 ~ 9223372036854775807 |

**推荐：**
- 主键使用INT UNSIGNED或BIGINT UNSIGNED
- 状态字段使用TINYINT

2. **字符串类型**

**CHAR vs VARCHAR：**
- CHAR：定长，适合长度固定的字段（如手机号、身份证号）
- VARCHAR：变长，节省空间

**TEXT类型：**
- 尽量避免使用TEXT、BLOB
- 如果必须使用，建议单独分表

3. **时间类型**

| 类型 | 字节 | 范围 |
|------|------|------|
| DATETIME | 8 | 1000-01-01 ~ 9999-12-31 |
| TIMESTAMP | 4 | 1970-01-01 ~ 2038-01-19 |

**推荐：**
- 使用DATETIME（存储范围更大）
- 或使用INT存储时间戳

#### 8.3.2 表设计规范

1. **使用自增主键**
   ```sql
   id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
   ```

2. **合理使用NOT NULL**
   - 能设置NOT NULL就设置
   - NULL值会占用额外空间，影响索引效率

3. **添加通用字段**
   ```sql
   create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
   update_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
   is_deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除'
   ```

4. **合理拆分表**
   - 垂直拆分：将不常用的字段拆到另一个表
   - 水平拆分：按某个字段分表（如按时间、地区）

### 8.4 配置优化

#### 8.4.1 连接相关

```ini
# 最大连接数
max_connections = 500

# 连接超时时间
wait_timeout = 28800
interactive_timeout = 28800
```

#### 8.4.2 Buffer Pool相关

```ini
# Buffer Pool大小（物理内存的50%-80%）
innodb_buffer_pool_size = 8G

# Buffer Pool实例数（建议设置为8）
innodb_buffer_pool_instances = 8
```

#### 8.4.3 日志相关

```ini
# redo log大小
innodb_log_file_size = 1G
innodb_log_files_in_group = 3

# redo log刷盘策略
innodb_flush_log_at_trx_commit = 1

# binlog刷盘策略
sync_binlog = 1
```

#### 8.4.4 其他优化

```ini
# 每个表独立表空间
innodb_file_per_table = ON

# 禁用查询缓存（MySQL 5.7）
query_cache_type = 0

# 排序缓冲大小
sort_buffer_size = 2M

# JOIN缓冲大小
join_buffer_size = 2M
```

### 8.5 分库分表

#### 8.5.1 垂直拆分

**垂直分库：** 按业务模块拆分数据库
```
原系统
  └─ 订单表
  └─ 用户表
  └─ 商品表

拆分后
订单库
  └─ 订单表
用户库
  └─ 用户表
商品库
  └─ 商品表
```

**垂直分表：** 将表中不常用的列拆到另一个表
```
原表 users
  └─ id, name, age, address, intro(TEXT)

拆分后
users
  └─ id, name, age

users_ext
  └─ user_id, address, intro
```

#### 8.5.2 水平拆分

**水平分库：** 按某个字段的值拆分到不同数据库
```
按用户ID取模
user_id % 4 = 0 -> db0
user_id % 4 = 1 -> db1
user_id % 4 = 2 -> db2
user_id % 4 = 3 -> db3
```

**水平分表：** 按某个字段的值拆分到不同表
```
按时间拆分
orders_202501
orders_202502
orders_202503
```

#### 8.5.3 分库分表中间件

- **ShardingSphere**（推荐）
- **MyCat**
- **TDDL**

---

## 第九部分：大厂高频面试题

### 9.1 基础篇

**Q1：InnoDB和MyISAM的区别？**

A：
| 特性 | InnoDB | MyISAM |
|------|--------|--------|
| 事务 | 支持 | 不支持 |
| 锁 | 行级锁 | 表级锁 |
| 外键 | 支持 | 不支持 |
| MVCC | 支持 | 不支持 |
| 崩溃恢复 | 支持（crash-safe） | 不支持 |

**Q2：MySQL的索引为什么使用B+树？**

A：
1. B+树的高度低，减少IO次数（3-4层可存储千万级数据）
2. 非叶子节点只存key，不存数据，可以存更多key
3. 叶子节点之间有指针，范围查询效率高
4. 所有数据都在叶子节点，查询性能稳定

**Q3：聚簇索引和非聚簇索引的区别？**

A：
- **聚簇索引**：叶子节点存储整行数据，一个表只有一个
- **非聚簇索引**：叶子节点存储主键值，需要回表

**Q4：什么是覆盖索引？**

A：查询的列都在索引中，不需要回表。可以减少IO，提升性能。

**Q5：联合索引的最左前缀原则是什么？**

A：对于联合索引(a, b, c)，查询条件必须包含最左边的列才能使用索引。
- WHERE a=1 ✅
- WHERE a=1 AND b=2 ✅
- WHERE b=2 ❌（跳过了a）

### 9.2 事务篇

**Q6：事务的ACID特性是什么？**

A：
- **原子性（Atomicity）**：事务是最小单位，不可分割
- **一致性（Consistency）**：事务前后数据完整性一致
- **隔离性（Isolation）**：多个事务互不干扰
- **持久性（Durability）**：事务提交后永久保存

**Q7：MySQL有哪些事务隔离级别？默认是哪个？**

A：
1. 读未提交（Read Uncommitted）
2. 读已提交（Read Committed）
3. 可重复读（Repeatable Read）- 默认
4. 串行化（Serializable）

**Q8：什么是MVCC？如何实现的？**

A：
- **MVCC**：多版本并发控制，读不加锁，读写不冲突
- **实现原理**：
  - 每行记录有隐藏列：事务ID、回滚指针
  - 通过undo log形成版本链
  - 通过ReadView判断版本可见性

**Q9：幻读是什么？InnoDB如何解决的？**

A：
- **幻读**：一个事务两次查询，结果集不一致（其他事务插入/删除了数据）
- **解决方案**：
  - 快照读：通过MVCC解决
  - 当前读：通过Next-Key Lock（记录锁+间隙锁）解决

### 9.3 锁机制篇

**Q10：MySQL有哪些锁？**

A：
1. **按粒度分：** 全局锁、表锁、行锁
2. **按模式分：** 共享锁（S锁）、排他锁（X锁）
3. **按算法分：** Record Lock、Gap Lock、Next-Key Lock

**Q11：什么是Next-Key Lock？**

A：
- Record Lock + Gap Lock
- 锁定记录和前面的间隙
- 用于防止幻读

**Q12：如何避免死锁？**

A：
1. 按相同顺序访问资源
2. 尽量使用主键索引
3. 控制事务大小，减少锁持有时间
4. 降低隔离级别（如果业务允许）
5. 添加合理的索引

### 9.4 日志篇

**Q13：redo log和binlog的区别？**

A：
| 特性 | redo log | binlog |
|------|----------|--------|
| 所属 | InnoDB | Server层 |
| 类型 | 物理日志（数据页修改） | 逻辑日志（SQL语句） |
| 写入 | 循环写（固定大小） | 追加写（不覆盖） |
| 作用 | crash-safe | 主从复制、数据恢复 |

**Q14：什么是两阶段提交？为什么需要？**

A：
- **两阶段提交**：先写redo log（prepare），再写binlog，最后提交redo log（commit）
- **目的**：保证redo log和binlog的一致性
- **场景**：防止MySQL crash时，两个日志不一致导致数据不一致

**Q15：binlog有哪些格式？推荐哪个？**

A：
1. **STATEMENT**：记录SQL语句，日志量小，可能主从不一致
2. **ROW**：记录每行变化，保证主从一致，日志量大（推荐）
3. **MIXED**：自动选择

### 9.5 性能优化篇

**Q16：如何定位慢SQL？**

A：
1. 开启慢查询日志
2. 使用EXPLAIN分析执行计划
3. 使用pt-query-digest分析慢查询日志
4. 查看performance_schema

**Q17：EXPLAIN的重要字段有哪些？**

A：
- **type**：访问类型，从好到坏：system > const > eq_ref > ref > range > index > ALL
- **key**：实际使用的索引
- **rows**：预计扫描的行数
- **Extra**：额外信息，关注"Using index"（覆盖索引）、"Using filesort"（文件排序）

**Q18：如何优化深分页查询？**

A：
1. 使用子查询：WHERE id >= (SELECT id FROM t LIMIT 10000, 1) LIMIT 10
2. 记录上次位置：WHERE id > last_id LIMIT 10
3. 使用ES等搜索引擎

**Q19：什么情况下索引会失效？**

A：
1. 使用!=、<>、NOT IN
2. LIKE以%开头
3. OR连接（有一个列没索引）
4. 对索引列使用函数
5. 隐式类型转换
6. 违反最左前缀原则

**Q20：如何设计索引？**

A：
1. 选择区分度高的列
2. 索引列不参与计算
3. 字符串索引加引号
4. 使用前缀索引（长字符串）
5. 使用联合索引而非多个单列索引
6. 覆盖索引优化查询

### 9.6 主从复制篇

**Q21：MySQL主从复制的原理？**

A：
1. 主库写入binlog
2. 从库IO线程拉取binlog，写入relay log
3. 从库SQL线程执行relay log

**Q22：主从延迟的原因和解决方案？**

A：
**原因：**
1. 从库性能差
2. 大事务
3. 从库SQL线程单线程执行
4. 网络延迟

**解决方案：**
1. 提升从库配置
2. 避免大事务
3. 使用并行复制
4. 对实时性要求高的读主库

**Q23：如何保证主从一致性？**

A：
1. 使用ROW格式的binlog
2. 使用半同步复制
3. 使用MGR（MySQL Group Replication）

### 9.7 架构设计篇

**Q24：如何设计一个高可用的MySQL架构？**

A：
1. **一主多从 + 读写分离**
2. **使用MHA或MGR实现自动故障切换**
3. **使用ProxySQL或中间件实现读写分离**
4. **定期备份，支持快速恢复**

**Q25：什么时候需要分库分表？**

A：
1. 单表数据量超过1000万
2. 单表数据大小超过10GB
3. 并发量大，单库无法支撑

**Q26：如何设计订单表的分库分表方案？**

A：
1. **水平分库**：按用户ID取模（user_id % 4）
2. **水平分表**：按时间分表（orders_202501）
3. **使用ShardingSphere等中间件**
4. **考虑扩容方案**：一致性哈希、double分片数

### 9.8 实战场景篇

**Q27：库存扣减如何防止超卖？**

A：
**方案1：使用行锁（FOR UPDATE）**
```sql
BEGIN;
SELECT stock FROM goods WHERE id=1 FOR UPDATE;
-- 判断库存是否足够
UPDATE goods SET stock = stock - 1 WHERE id=1;
COMMIT;
```

**方案2：使用乐观锁（版本号）**
```sql
UPDATE goods SET stock = stock - 1, version = version + 1 
WHERE id=1 AND stock > 0 AND version = #{old_version};
```

**方案3：使用Redis + Lua脚本**

**Q28：如何设计一个秒杀系统的数据库？**

A：
1. **使用Redis扣减库存**（减少数据库压力）
2. **异步写入MySQL**（消息队列）
3. **分库分表**（按商品ID或用户ID）
4. **使用行级锁防止超卖**
5. **限流 + 防刷**

**Q29：误删数据如何恢复？**

A：
1. 如果有全量备份：恢复备份 + 重放binlog
2. 如果开启了binlog：使用binlog进行闪回
3. 如果有从库：从从库恢复数据
4. **预防措施：**
   - 使用逻辑删除（is_deleted字段）
   - 定期备份
   - 开启binlog
   - 权限控制（禁止直接DELETE）

**Q30：如何优化千万级数据的COUNT查询？**

A：
1. **使用缓存**（Redis）存储count值
2. **使用汇总表**（定期统计）
3. **使用ES等搜索引擎**
4. **如果允许不精确，使用EXPLAIN估算**
   ```sql
   EXPLAIN SELECT COUNT(*) FROM users;
   -- rows字段是估算值
   ```

---

## 总结

### MySQL学习路径

```
基础阶段
  ├─ MySQL架构
  ├─ SQL语法
  └─ 存储引擎

进阶阶段
  ├─ 索引原理
  ├─ 事务与锁
  └─ 日志系统

高级阶段
  ├─ 主从复制
  ├─ 性能优化
  └─ 高可用架构

实战阶段
  ├─ 大数据量优化
  ├─ 分库分表
  └─ 业务场景设计
```

### 核心知识点总结

1. **索引是性能优化的关键**
   - 理解B+树原理
   - 掌握索引设计原则
   - 避免索引失效

2. **事务隔离靠MVCC**
   - 理解版本链和ReadView
   - 掌握隔离级别的区别
   - 理解幻读的解决方案

3. **日志保证数据安全**
   - redo log保证crash-safe
   - binlog用于复制和恢复
   - 两阶段提交保证一致性

4. **锁机制提升并发**
   - 行级锁提升并发
   - Next-Key Lock防止幻读
   - 避免死锁

5. **主从复制实现高可用**
   - 理解复制原理
   - 解决主从延迟
   - 设计高可用架构

### 学习建议

1. **理论结合实践**
   - 搭建本地MySQL环境
   - 实际操作验证理论

2. **多看源码和文档**
   - 阅读MySQL官方文档
   - 学习优秀的源码分析文章

3. **关注性能优化**
   - 使用EXPLAIN分析SQL
   - 监控慢查询日志
   - 学习优化案例

4. **准备面试**
   - 掌握高频面试题
   - 理解底层原理
   - 准备实战案例

---

## 参考资料

1. **《MySQL实战45讲》**（丁奇）- 极客时间
2. **《高性能MySQL》**（第4版）
3. **《MySQL技术内幕：InnoDB存储引擎》**（第2版）
4. **MySQL官方文档**：https://dev.mysql.com/doc/
5. **阿里云数据库内核月报**

---

**持续更新中...**

如有问题或建议，欢迎交流讨论！

