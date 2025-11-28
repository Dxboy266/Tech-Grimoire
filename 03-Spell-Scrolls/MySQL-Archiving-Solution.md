# MySQL生产级大表归档方案

> 版本：v1.0  
> 适用场景：千万级数据表归档  
> 测试环境：MySQL 5.7 / 8.0

---

## 一、归档方案总览

| 方案 | MySQL版本 | 1000w数据耗时 | 锁表时间 | 业务影响 | 适用场景 |
|------|-----------|--------------|---------|---------|---------|
| **1. RENAME原子交换** | 5.6+ | <1秒 | <100ms | 几乎无 | 全量清空归档 ⭐⭐⭐⭐⭐ |
| **2. 先插后建索引** | 5.5+ | 7-12分钟 | 5-8分钟 | 写入阻塞 | 可短时维护窗口 ⭐⭐⭐⭐ |
| **3. 分批归档** | 5.5+ | 15-30分钟 | 每批<3秒 | 写入偶尔慢 | 24小时业务 ⭐⭐⭐⭐⭐ |
| **4. 按条件归档** | 5.5+ | 视数据量 | 视数据量 | 写入阻塞 | 保留部分数据 ⭐⭐⭐⭐ |
| **5. pt-archiver** | 5.5+ | 12-25分钟 | 每批<1秒 | 写入偶尔慢 | DBA专业工具 ⭐⭐⭐⭐ |
| **6. 分区表** | 5.7+ | <5秒 | <5秒 | 几乎无 | 长期规范化管理 ⭐⭐⭐⭐⭐ |

---

## 二、核心语法差异对比

### 2.1 表重命名语法

#### RENAME TABLE（推荐）

```sql
-- 单表重命名
RENAME TABLE old_table TO old_table_bak;

-- 原子交换（多表同时重命名）✅
RENAME TABLE 
  t_old TO t_old_bak,
  t_new TO t_old;
```

**特性：**
- ✅ 支持原子操作（多表同时交换）
- ✅ 支持跨库重命名
- ✅ 只修改元数据，<100ms完成
- ✅ MySQL 5.6+

---

#### ALTER TABLE RENAME（不推荐用于归档）

```sql
-- 只能单表操作
ALTER TABLE old_table RENAME TO old_table_bak;
```

**特性：**
- ❌ 不支持原子操作
- ❌ 不支持跨库
- ⚠️ 单次操作有"表不存在"间隙

**关键差异示例：**
```sql
-- ❌ 错误示范：ALTER无法原子交换
ALTER TABLE t1 RENAME TO t1_bak;  -- 此时t1消失，业务报错
ALTER TABLE t1_new RENAME TO t1;  -- 业务才恢复

-- ✅ 正确示范：RENAME原子交换
RENAME TABLE t1 TO t1_bak, t1_new TO t1;  -- 同时完成，无间隙
```

---

### 2.2 建索引语法

#### ALTER TABLE ADD INDEX（推荐建多索引）

```sql
-- 一次性建多个索引（MySQL 8.0优化：只扫表1次）✅
ALTER TABLE t_table 
ADD KEY idx_col1 (col1),
ADD KEY idx_col2 (col2),
ADD KEY idx_col3 (col3);
```

**特性：**
- ✅ MySQL 8.0：一次扫表建所有索引
- ✅ MySQL 5.7：需扫多次表，但只加锁一次
- ⏱️ 1000w数据，3个索引：2-4分钟

---

#### CREATE INDEX（适用于单索引）

```sql
-- 建单个索引
CREATE INDEX idx_col1 ON t_table(col1);
CREATE INDEX idx_col2 ON t_table(col2);
CREATE INDEX idx_col3 ON t_table(col3);
```

**特性：**
- ⚠️ 每个索引扫一次表
- ⏱️ 1000w数据，3个索引：6-9分钟
- MySQL 5.5+

**效率对比（1000w数据）：**
| 方法 | MySQL 5.7 | MySQL 8.0 | 推荐度 |
|------|-----------|-----------|--------|
| ALTER TABLE ADD (3个索引) | 4-6分钟 | 2-4分钟 ✅ | ⭐⭐⭐⭐⭐ |
| CREATE INDEX × 3 | 6-9分钟 | 6-9分钟 | ⭐⭐⭐ |

---

### 2.3 创建表语法

#### CREATE TABLE ... LIKE

```sql
CREATE TABLE t_new LIKE t_old;
```

**复制内容：**
- ✅ 表结构
- ✅ 主键
- ✅ 所有索引
- ✅ 字符集/排序规则
- ❌ 不复制数据
- ❌ 不复制外键
- ❌ 不复制触发器

---

#### CREATE TABLE ... AS SELECT

```sql
CREATE TABLE t_new AS SELECT * FROM t_old WHERE 1=0;
```

**复制内容：**
- ✅ 表结构
- ✅ 数据（WHERE 1=0时不复制）
- ❌ **不复制索引**（需手动创建）
- ❌ 不复制主键

---

## 三、生产级归档方案详解

### 方案1：RENAME原子交换（最快，适合全量清空）

#### 适用场景
- ✅ 全量归档，清空原表
- ✅ 可接受<100ms的短暂锁定
- ✅ 日志表、临时表、历史表

#### MySQL版本要求
- MySQL 5.6+（支持在线DDL）
- MySQL 8.0（最佳）

#### 执行步骤

```sql
-- ========== 准备阶段（业务低峰期提前执行） ==========

-- Step 1: 创建空表（0.1秒，不影响业务）
CREATE TABLE interfacecenter.t_xapi_log_info_new 
LIKE interfacecenter.t_xapi_log_info;

-- Step 2: 验证表结构
SHOW CREATE TABLE interfacecenter.t_xapi_log_info_new;


-- ========== 归档阶段（凌晨2-4点执行） ==========

-- Step 3: 原子交换（<100ms完成）
RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_251021bak,
  interfacecenter.t_xapi_log_info_new TO interfacecenter.t_xapi_log_info;


-- ========== 验证阶段 ==========

-- Step 4: 验证归档结果
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info;  -- 应为0
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info_251021bak;  -- 应为10000000

-- Step 5: 验证业务正常
-- 观察应用日志，确认新日志正常写入
```

#### 时间消耗
- 准备阶段：0.1秒
- 归档阶段：<0.1秒
- **总耗时：<1秒**

#### 业务影响
- 锁表时间：<100ms
- 写入阻塞：<100ms（用户无感知）
- 查询影响：无

#### 注意事项
1. ⚠️ 归档后原表为空，所有数据进入备份表
2. ⚠️ 确保应用连接池超时>100ms（一般都>3秒）
3. ✅ 可在凌晨低峰期执行，几乎无风险

---

### 方案2：先插入后建索引（适合可短时维护）

#### 适用场景
- ✅ 可接受5-10分钟维护窗口
- ✅ 需要保留备份表的完整索引
- ✅ 追求归档速度（比直接LIKE快40%）

#### MySQL版本要求
- MySQL 5.5+（通用）
- MySQL 8.0（建索引最快）

#### 执行步骤

```sql
-- ========== MySQL 8.0 版本（推荐） ==========

-- Step 1: 手动创建表（仅主键，不含二级索引）
CREATE TABLE interfacecenter.t_xapi_log_info_251021bak (
  `LOG_ID` varchar(32) NOT NULL COMMENT '主键',
  `API_LABEL` varchar(50) DEFAULT NULL COMMENT '接口编码',
  `OBJECT_TYPE` varchar(32) DEFAULT NULL COMMENT '接口类型',
  `IN_DATA` longtext COMMENT '接收数据',
  `OUT_DATA` longtext COMMENT '发送数据',
  `LOG_STATUS` varchar(2) DEFAULT NULL COMMENT '状态',
  `LOG_TIME` datetime DEFAULT NULL COMMENT '开始时间',
  `LOG_TIME_END` datetime DEFAULT NULL COMMENT '结束时间',
  `LOG_MESSAGE` varchar(200) DEFAULT NULL COMMENT '提示语',
  `SERIAL_NUM` varchar(36) DEFAULT NULL COMMENT '流水号',
  PRIMARY KEY (`LOG_ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci 
COMMENT='接口日志表-归档备份';

-- Step 2: 批量插入数据（5-8分钟，无二级索引快40%）
-- 建议：凌晨2点执行，避开业务高峰
INSERT INTO interfacecenter.t_xapi_log_info_251021bak 
SELECT * FROM interfacecenter.t_xapi_log_info;

-- 验证数据量
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info_251021bak;

-- Step 3: 一次性建所有索引（MySQL 8.0只扫表1次，2-4分钟）
ALTER TABLE interfacecenter.t_xapi_log_info_251021bak 
ADD KEY `IDX_t_XAPI_LOG_INFO_01` (`API_LABEL`) USING BTREE,
ADD KEY `IDX_t_XAPI_LOG_INFO_02` (`LOG_TIME`) USING BTREE,
ADD KEY `IDX_t_XAPI_LOG_INFO_03` (`SERIAL_NUM`) USING BTREE;

-- Step 4: 清空原表（<1秒）
TRUNCATE TABLE interfacecenter.t_xapi_log_info;


-- ========== MySQL 5.7 版本（兼容方案） ==========

-- Step 1-2: 同上

-- Step 3: MySQL 5.7建索引（仍建议用ALTER TABLE）
-- 虽然会扫表多次，但只加锁一次，比CREATE INDEX好
ALTER TABLE interfacecenter.t_xapi_log_info_251021bak 
ADD KEY `IDX_t_XAPI_LOG_INFO_01` (`API_LABEL`) USING BTREE,
ADD KEY `IDX_t_XAPI_LOG_INFO_02` (`LOG_TIME`) USING BTREE,
ADD KEY `IDX_t_XAPI_LOG_INFO_03` (`SERIAL_NUM`) USING BTREE;
-- MySQL 5.7耗时：4-6分钟

-- Step 4: 同上
```

#### 时间消耗（1000w数据）
| 步骤 | MySQL 5.7 | MySQL 8.0 |
|------|-----------|-----------|
| 插入数据 | 6-8分钟 | 5-8分钟 |
| 建3个索引 | 4-6分钟 | 2-4分钟 |
| TRUNCATE | <1秒 | <1秒 |
| **总计** | **10-14分钟** | **7-12分钟** |

#### 业务影响
- 插入阶段（5-8分钟）：
  - ✅ 查询正常
  - ❌ 写入阻塞（被共享锁阻塞）
- 建索引阶段（2-6分钟）：
  - ✅ 源表完全不受影响
- TRUNCATE阶段（<1秒）：
  - ⚠️ 短暂锁表

#### 优化建议
```sql
-- 可选优化1：关闭binlog（提速30%，但主从同步会失效）
SET SESSION sql_log_bin=0;
INSERT INTO t_bak SELECT * FROM t_source;
SET SESSION sql_log_bin=1;

-- 可选优化2：调整批量插入参数
SET SESSION bulk_insert_buffer_size = 256*1024*1024;  -- 256MB

-- 可选优化3：禁用唯一性检查（如果确定无重复）
SET SESSION unique_checks=0;
INSERT INTO t_bak SELECT * FROM t_source;
SET SESSION unique_checks=1;
```

---

### 方案3：分批归档（适合不能停服场景）

#### 适用场景
- ✅ 7×24小时业务，不能停服
- ✅ 可接受15-30分钟归档时间
- ✅ 写入量不大（每秒<1000条）

#### MySQL版本要求
- MySQL 5.5+（通用方案）

#### 执行步骤

```sql
-- ========== 准备阶段 ==========

-- Step 1: 创建备份表
CREATE TABLE interfacecenter.t_xapi_log_info_251021bak 
LIKE interfacecenter.t_xapi_log_info;


-- ========== 归档阶段 ==========

-- Step 2: 创建分批归档存储过程
DELIMITER $$

CREATE PROCEDURE sp_archive_xapi_log(
  IN p_batch_size INT,      -- 每批数量（建议5w-10w）
  IN p_sleep_ms INT         -- 每批后暂停毫秒数（建议50-100）
)
BEGIN
  DECLARE v_rows INT DEFAULT 1;
  DECLARE v_total INT DEFAULT 0;
  DECLARE v_archived INT DEFAULT 0;
  DECLARE v_start_time DATETIME;
  DECLARE v_batch_count INT DEFAULT 0;
  
  -- 获取总数
  SELECT COUNT(*) INTO v_total FROM interfacecenter.t_xapi_log_info;
  SET v_start_time = NOW();
  
  SELECT CONCAT('开始归档，总数据量: ', v_total, ' 条') AS info;
  
  WHILE v_rows > 0 DO
    -- 插入一批数据
    INSERT INTO interfacecenter.t_xapi_log_info_251021bak
    SELECT * FROM interfacecenter.t_xapi_log_info
    ORDER BY LOG_ID
    LIMIT p_batch_size;
    
    SET v_rows = ROW_COUNT();
    SET v_archived = v_archived + v_rows;
    SET v_batch_count = v_batch_count + 1;
    
    -- 删除已归档的数据
    IF v_rows > 0 THEN
      DELETE FROM interfacecenter.t_xapi_log_info
      ORDER BY LOG_ID
      LIMIT p_batch_size;
      
      -- 显示进度（每10批显示一次）
      IF v_batch_count % 10 = 0 THEN
        SELECT CONCAT(
          '进度: ', v_archived, '/', v_total, 
          ' (', ROUND(v_archived/v_total*100, 2), '%)',
          ' | 已耗时: ', TIMESTAMPDIFF(MINUTE, v_start_time, NOW()), '分钟'
        ) AS progress;
      END IF;
      
      -- 提交事务
      COMMIT;
      
      -- 暂停，释放锁，让其他事务执行
      DO SLEEP(p_sleep_ms / 1000);
    END IF;
  END WHILE;
  
  SELECT CONCAT(
    '归档完成！总数据量: ', v_total, 
    ' | 总耗时: ', TIMESTAMPDIFF(MINUTE, v_start_time, NOW()), '分钟'
  ) AS result;
END$$

DELIMITER ;


-- Step 3: 执行归档
-- 每批5w条，每批后暂停50ms
CALL sp_archive_xapi_log(50000, 50);


-- Step 4: 验证结果
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info;  -- 应为0
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info_251021bak;  -- 应为10000000


-- Step 5: 清理存储过程
DROP PROCEDURE IF EXISTS sp_archive_xapi_log;
```

#### 时间消耗
- 1000w数据 ÷ 5w/批 = 200批
- 每批耗时：2-3秒（插入+删除）
- 每批暂停：50ms
- **总耗时：15-30分钟**

#### 业务影响
- 每批锁表：2-3秒
- 每批暂停：50ms（其他事务可执行）
- 用户体验：写入偶尔慢2-3秒
- **几乎无感知**

#### 参数调优
```sql
-- 高性能服务器，写入量小
CALL sp_archive_xapi_log(100000, 10);  -- 每批10w，暂停10ms

-- 普通服务器，写入量大
CALL sp_archive_xapi_log(30000, 100);  -- 每批3w，暂停100ms

-- 低配服务器，业务繁忙
CALL sp_archive_xapi_log(10000, 200);  -- 每批1w，暂停200ms
```

---

### 方案4：按条件归档（适合保留部分数据）

#### 适用场景
- ✅ 仅归档历史数据（如保留近30天）
- ✅ 按时间/状态等条件过滤
- ✅ 源表需继续使用

#### 执行步骤

```sql
-- ========== 示例：归档30天前的数据 ==========

-- Step 1: 创建备份表
CREATE TABLE interfacecenter.t_xapi_log_info_251021bak 
LIKE interfacecenter.t_xapi_log_info;

-- Step 2: 归档旧数据（带WHERE条件）
INSERT INTO interfacecenter.t_xapi_log_info_251021bak 
SELECT * FROM interfacecenter.t_xapi_log_info 
WHERE LOG_TIME < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Step 3: 删除已归档数据（分批删除，避免长时间锁表）
-- 方法1：一次性删除（如果数据量不大）
DELETE FROM interfacecenter.t_xapi_log_info 
WHERE LOG_TIME < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- 方法2：分批删除（推荐，1000w数据）
DELIMITER $$
CREATE PROCEDURE sp_delete_old_logs()
BEGIN
  DECLARE v_rows INT DEFAULT 1;
  WHILE v_rows > 0 DO
    DELETE FROM interfacecenter.t_xapi_log_info 
    WHERE LOG_TIME < DATE_SUB(NOW(), INTERVAL 30 DAY)
    ORDER BY LOG_ID
    LIMIT 50000;
    
    SET v_rows = ROW_COUNT();
    DO SLEEP(0.05);
  END WHILE;
END$$
DELIMITER ;

CALL sp_delete_old_logs();
DROP PROCEDURE sp_delete_old_logs;
```

---

### 方案5：pt-archiver工具（DBA专业方案）

#### 适用场景
- ✅ 有DBA团队，熟悉Percona工具
- ✅ 需要断点续传、限流控制
- ✅ 需要详细的归档统计

#### MySQL版本要求
- MySQL 5.5+
- 需安装Percona Toolkit

#### 安装pt-archiver

```bash
# CentOS/RHEL
yum install percona-toolkit

# Ubuntu/Debian
apt-get install percona-toolkit

# 验证安装
pt-archiver --version
```

#### 执行命令

```bash
# 基础归档命令
pt-archiver \
  --source h=127.0.0.1,P=3306,u=root,p='password',D=interfacecenter,t=t_xapi_log_info \
  --dest h=127.0.0.1,P=3306,u=root,p='password',D=interfacecenter,t=t_xapi_log_info_251021bak \
  --where "1=1" \
  --limit 10000 \
  --commit-each \
  --progress 100000 \
  --statistics

# 高级参数示例
pt-archiver \
  --source h=127.0.0.1,P=3306,u=root,p='password',D=interfacecenter,t=t_xapi_log_info \
  --dest h=127.0.0.1,P=3306,u=root,p='password',D=interfacecenter,t=t_xapi_log_info_251021bak \
  --where "LOG_TIME < DATE_SUB(NOW(), INTERVAL 30 DAY)" \
  --limit 10000 \
  --txn-size 10000 \
  --commit-each \
  --progress 100000 \
  --sleep 10 \
  --check-charset \
  --check-columns \
  --bulk-delete \
  --purge
```

#### 参数说明

| 参数 | 说明 | 推荐值 |
|------|------|--------|
| `--limit` | 每批处理行数 | 10000 |
| `--txn-size` | 事务大小 | 10000 |
| `--commit-each` | 每批提交一次 | 必加 |
| `--progress` | 进度显示间隔 | 100000 |
| `--sleep` | 每批后暂停(ms) | 10-100 |
| `--purge` | 归档后删除源数据 | 视需求 |
| `--bulk-delete` | 批量删除 | 推荐 |

#### 时间消耗
- 1000w数据：12-25分钟
- 每批锁表：<1秒

---

### 方案6：分区表（长期规范化方案）

#### 适用场景
- ✅ 长期需要定期归档
- ✅ 数据按时间维度增长
- ✅ 可接受一次性改造成本

#### MySQL版本要求
- MySQL 5.7+（支持在线分区）
- MySQL 8.0（最佳）

#### 改造步骤

```sql
-- ========== Step 1: 创建分区表 ==========

CREATE TABLE interfacecenter.t_xapi_log_info_partitioned (
  `LOG_ID` varchar(32) NOT NULL COMMENT '主键',
  `API_LABEL` varchar(50) DEFAULT NULL,
  `OBJECT_TYPE` varchar(32) DEFAULT NULL,
  `IN_DATA` longtext,
  `OUT_DATA` longtext,
  `LOG_STATUS` varchar(2) DEFAULT NULL,
  `LOG_TIME` datetime NOT NULL COMMENT '开始时间',  -- 注意：NOT NULL
  `LOG_TIME_END` datetime DEFAULT NULL,
  `LOG_MESSAGE` varchar(200) DEFAULT NULL,
  `SERIAL_NUM` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`LOG_ID`, `LOG_TIME`) USING BTREE,  -- 注意：LOG_TIME加入主键
  KEY `IDX_t_XAPI_LOG_INFO_01` (`API_LABEL`) USING BTREE,
  KEY `IDX_t_XAPI_LOG_INFO_02` (`LOG_TIME`) USING BTREE,
  KEY `IDX_t_XAPI_LOG_INFO_03` (`SERIAL_NUM`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
PARTITION BY RANGE (TO_DAYS(LOG_TIME)) (
  PARTITION p202407 VALUES LESS THAN (TO_DAYS('2024-08-01')),
  PARTITION p202408 VALUES LESS THAN (TO_DAYS('2024-09-01')),
  PARTITION p202409 VALUES LESS THAN (TO_DAYS('2024-10-01')),
  PARTITION p202410 VALUES LESS THAN (TO_DAYS('2024-11-01')),
  PARTITION p202411 VALUES LESS THAN (TO_DAYS('2024-12-01')),
  PARTITION p_max VALUES LESS THAN MAXVALUE
);


-- ========== Step 2: 迁移数据 ==========

-- 低峰期执行（10-20分钟）
INSERT INTO interfacecenter.t_xapi_log_info_partitioned 
SELECT * FROM interfacecenter.t_xapi_log_info;


-- ========== Step 3: 原子切换 ==========

RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_old,
  interfacecenter.t_xapi_log_info_partitioned TO interfacecenter.t_xapi_log_info;


-- ========== Step 4: 后续归档（秒级完成） ==========

-- 方法1：删除整个分区（数据丢失）
ALTER TABLE interfacecenter.t_xapi_log_info DROP PARTITION p202407;

-- 方法2：分区数据归档到其他表
CREATE TABLE interfacecenter.t_xapi_log_info_202407 
LIKE interfacecenter.t_xapi_log_info;

ALTER TABLE interfacecenter.t_xapi_log_info_202407 REMOVE PARTITIONING;

ALTER TABLE interfacecenter.t_xapi_log_info 
EXCHANGE PARTITION p202407 
WITH TABLE interfacecenter.t_xapi_log_info_202407;

-- 删除分区
ALTER TABLE interfacecenter.t_xapi_log_info DROP PARTITION p202407;


-- ========== Step 5: 定期添加新分区 ==========

-- 每月1号凌晨执行
ALTER TABLE interfacecenter.t_xapi_log_info 
ADD PARTITION (
  PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01'))
);
```

#### 注意事项
1. ⚠️ 分区字段（LOG_TIME）必须在主键中
2. ⚠️ 分区字段不能为NULL
3. ⚠️ 改造期间需停服或双写
4. ✅ 改造后归档只需<5秒

#### 自动化脚本（每月归档）

```sql
-- 创建归档存储过程
DELIMITER $$

CREATE PROCEDURE sp_monthly_archive_partition()
BEGIN
  DECLARE v_partition_name VARCHAR(20);
  DECLARE v_archive_table VARCHAR(100);
  DECLARE v_date DATE;
  
  -- 归档3个月前的分区
  SET v_date = DATE_SUB(CURDATE(), INTERVAL 3 MONTH);
  SET v_partition_name = CONCAT('p', DATE_FORMAT(v_date, '%Y%m'));
  SET v_archive_table = CONCAT('t_xapi_log_info_', DATE_FORMAT(v_date, '%Y%m'));
  
  -- 创建归档表
  SET @sql = CONCAT('CREATE TABLE IF NOT EXISTS interfacecenter.', v_archive_table, 
                    ' LIKE interfacecenter.t_xapi_log_info');
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  
  -- 移除分区属性
  SET @sql = CONCAT('ALTER TABLE interfacecenter.', v_archive_table, ' REMOVE PARTITIONING');
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  
  -- 交换分区
  SET @sql = CONCAT('ALTER TABLE interfacecenter.t_xapi_log_info EXCHANGE PARTITION ', 
                    v_partition_name, ' WITH TABLE interfacecenter.', v_archive_table);
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  
  -- 删除分区
  SET @sql = CONCAT('ALTER TABLE interfacecenter.t_xapi_log_info DROP PARTITION ', v_partition_name);
  PREPARE stmt FROM @sql;
  EXECUTE stmt;
  
  SELECT CONCAT('归档完成: ', v_partition_name, ' -> ', v_archive_table) AS result;
END$$

DELIMITER ;

-- 定时任务（每月1号执行）
-- 配合Linux crontab或MySQL事件调度器
CREATE EVENT IF NOT EXISTS evt_monthly_archive
ON SCHEDULE EVERY 1 MONTH
STARTS '2024-11-01 02:00:00'
DO CALL sp_monthly_archive_partition();
```

---

## 四、不同MySQL版本的最佳方案

### MySQL 5.5 / 5.6

**推荐方案：** 分批归档（方案3）

```sql
-- 最稳妥的通用方案
CREATE TABLE t_bak LIKE t_source;

DELIMITER $$
CREATE PROCEDURE sp_archive()
BEGIN
  DECLARE v_rows INT DEFAULT 1;
  WHILE v_rows > 0 DO
    INSERT INTO t_bak SELECT * FROM t_source ORDER BY id LIMIT 50000;
    SET v_rows = ROW_COUNT();
    DELETE FROM t_source ORDER BY id LIMIT 50000;
    DO SLEEP(0.05);
  END WHILE;
END$$
DELIMITER ;

CALL sp_archive();
```

**原因：**
- 5.5/5.6 在线DDL能力有限
- 分批方案最安全，业务影响最小

---

### MySQL 5.7

**推荐方案1：** RENAME原子交换（全量清空）
**推荐方案2：** 先插后建索引（需维护窗口）

```sql
-- 方案1：全量清空
CREATE TABLE t_new LIKE t_source;
RENAME TABLE t_source TO t_bak, t_new TO t_source;

-- 方案2：先插后索引（建索引会扫表多次，但比5.5快）
CREATE TABLE t_bak (主键定义);
INSERT INTO t_bak SELECT * FROM t_source;
ALTER TABLE t_bak ADD INDEX idx1(col1), ADD INDEX idx2(col2);
TRUNCATE TABLE t_source;
```

---

### MySQL 8.0

**推荐方案1：** RENAME原子交换（最快）
**推荐方案2：** 先插后建索引（优化版）
**长期方案：** 改造为分区表

```sql
-- 方案1：最快（<1秒）
CREATE TABLE t_new LIKE t_source;
RENAME TABLE t_source TO t_bak, t_new TO t_source;

-- 方案2：先插后索引（8.0建索引只扫表1次）
CREATE TABLE t_bak (主键定义);
INSERT INTO t_bak SELECT * FROM t_source;
ALTER TABLE t_bak 
ADD INDEX idx1(col1),  -- 一次性建多个索引，只扫表1次✅
ADD INDEX idx2(col2),
ADD INDEX idx3(col3);
TRUNCATE TABLE t_source;
```

---

## 五、归档方案决策树

```
开始
 │
 ├─ 是否全量清空原表？
 │   ├─ 是 → 使用【RENAME原子交换】（<1秒）✅
 │   └─ 否 → 继续判断
 │
 ├─ 是否可以接受5-10分钟维护窗口？
 │   ├─ 是 → 使用【先插后建索引】（7-12分钟）
 │   └─ 否 → 使用【分批归档】（15-30分钟，每批<3秒）
 │
 ├─ 是否长期需要定期归档？
 │   ├─ 是 → 改造为【分区表】（后续<5秒/次）
 │   └─ 否 → 使用上述一次性方案
 │
 └─ 是否有DBA团队？
     ├─ 是 → 可选【pt-archiver】（专业工具）
     └─ 否 → 使用存储过程方案
```

---

## 六、针对t_xapi_log_info表的具体建议

### 表结构分析

```sql
CREATE TABLE `t_xapi_log_info` (
  `LOG_ID` varchar(32) NOT NULL COMMENT '主键',
  `API_LABEL` varchar(50) DEFAULT NULL COMMENT '接口编码',
  `OBJECT_TYPE` varchar(32) DEFAULT NULL COMMENT '接口类型',
  `IN_DATA` longtext COMMENT '接收数据',  -- ⚠️ 大字段
  `OUT_DATA` longtext COMMENT '发送数据',  -- ⚠️ 大字段
  `LOG_STATUS` varchar(2) DEFAULT NULL,
  `LOG_TIME` datetime DEFAULT NULL COMMENT '开始时间',  -- ✅ 适合分区
  `LOG_TIME_END` datetime DEFAULT NULL,
  `LOG_MESSAGE` varchar(200) DEFAULT NULL,
  `SERIAL_NUM` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`LOG_ID`),
  KEY `IDX_t_XAPI_LOG_INFO_01` (`API_LABEL`),
  KEY `IDX_t_XAPI_LOG_INFO_02` (`LOG_TIME`),
  KEY `IDX_t_XAPI_LOG_INFO_03` (`SERIAL_NUM`)
) ENGINE=InnoDB;
```

**特点：**
- ⚠️ 有2个longtext字段，数据量大
- ✅ 有LOG_TIME字段，适合按时间分区
- ✅ 日志表，通常全量归档清空

---

### 本次归档执行方案（1000w数据）

#### 推荐方案：RENAME原子交换

```sql
-- ========== 执行时间：2024-10-21 凌晨2:00 ==========

-- Step 1: 19:00提前创建空表（不影响业务）
CREATE TABLE interfacecenter.t_xapi_log_info_new 
LIKE interfacecenter.t_xapi_log_info;

-- 验证表结构
SHOW CREATE TABLE interfacecenter.t_xapi_log_info_new;

-- Step 2: 02:00执行原子交换（<100ms）
RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_251021bak,
  interfacecenter.t_xapi_log_info_new TO interfacecenter.t_xapi_log_info;

-- Step 3: 验证
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info;  -- 0
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info_251021bak;  -- 10000000

-- Step 4: 查看备份表大小
SELECT 
  table_name,
  ROUND(data_length/1024/1024, 2) AS data_mb,
  ROUND(index_length/1024/1024, 2) AS index_mb,
  ROUND((data_length+index_length)/1024/1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema='interfacecenter' 
  AND table_name LIKE 't_xapi_log_info%';
```

**执行时间线：**
- 19:00 - 创建空表（0.1秒）
- 02:00 - 执行RENAME（0.05秒）
- 02:00:01 - 归档完成 ✅

**业务影响：**
- 锁表时间：<100ms
- 用户感知：无

---

### 长期优化建议：改造为分区表

```sql
-- ========== 下次维护窗口执行（建议凌晨） ==========

-- Step 1: 创建分区表
CREATE TABLE interfacecenter.t_xapi_log_info_partitioned (
  `LOG_ID` varchar(32) NOT NULL,
  `API_LABEL` varchar(50) DEFAULT NULL,
  `OBJECT_TYPE` varchar(32) DEFAULT NULL,
  `IN_DATA` longtext,
  `OUT_DATA` longtext,
  `LOG_STATUS` varchar(2) DEFAULT NULL,
  `LOG_TIME` datetime NOT NULL,  -- 改为NOT NULL
  `LOG_TIME_END` datetime DEFAULT NULL,
  `LOG_MESSAGE` varchar(200) DEFAULT NULL,
  `SERIAL_NUM` varchar(36) DEFAULT NULL,
  PRIMARY KEY (`LOG_ID`, `LOG_TIME`),  -- LOG_TIME加入主键
  KEY `IDX_t_XAPI_LOG_INFO_01` (`API_LABEL`),
  KEY `IDX_t_XAPI_LOG_INFO_02` (`LOG_TIME`),
  KEY `IDX_t_XAPI_LOG_INFO_03` (`SERIAL_NUM`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
PARTITION BY RANGE (TO_DAYS(LOG_TIME)) (
  PARTITION p202410 VALUES LESS THAN (TO_DAYS('2024-11-01')),
  PARTITION p202411 VALUES LESS THAN (TO_DAYS('2024-12-01')),
  PARTITION p202412 VALUES LESS THAN (TO_DAYS('2025-01-01')),
  PARTITION p_max VALUES LESS THAN MAXVALUE
);

-- Step 2: 迁移当前数据（需停服或双写）
INSERT INTO interfacecenter.t_xapi_log_info_partitioned 
SELECT * FROM interfacecenter.t_xapi_log_info;

-- Step 3: 原子切换
RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_old,
  interfacecenter.t_xapi_log_info_partitioned TO interfacecenter.t_xapi_log_info;

-- Step 4: 后续每月归档只需5秒
-- 每月1号执行
ALTER TABLE interfacecenter.t_xapi_log_info DROP PARTITION p202410;
```

**长期收益：**
- 每月归档从15分钟 → 5秒
- 查询性能提升（分区裁剪）
- 数据管理更规范

---

## 七、常见问题FAQ

### Q1: RENAME TABLE会丢数据吗？

**A:** 不会。RENAME只是修改表名映射，数据文件完整保留。

```sql
-- 归档前
t_xapi_log_info.ibd (10GB数据文件)

-- RENAME后
t_xapi_log_info_bak.ibd (同一个10GB文件，只是改名)
```

---

### Q2: 分批归档期间，新写入的数据会被归档吗？

**A:** 不会。使用`ORDER BY id LIMIT`方式，每批归档的是固定范围的数据。

```sql
-- 第1批：归档id 1-50000
INSERT INTO t_bak SELECT * FROM t WHERE id BETWEEN 1 AND 50000;
DELETE FROM t WHERE id BETWEEN 1 AND 50000;

-- 此时新写入的id=50001+的数据不受影响
-- 第2批：归档id 50001-100000
```

---

### Q3: 为什么先插后建索引更快？

**A:** 插入时维护索引开销大。

```
场景1：表已有索引
每插入1行 → 更新4个索引（1主键+3二级索引）
1000w行 × 4索引 = 4000w次B+树更新

场景2：先插后建索引
插入1000w行 → 只更新主键索引 = 1000w次
然后一次性建3个索引 = 扫表1次（MySQL 8.0）

速度提升：30-40%
```

---

### Q4: ALTER TABLE ADD INDEX 和 CREATE INDEX有什么区别？

**MySQL 8.0：**
```sql
-- ALTER TABLE：一次扫表建所有索引（推荐）
ALTER TABLE t ADD INDEX idx1(col1), ADD INDEX idx2(col2);
-- 扫表1次，耗时2分钟

-- CREATE INDEX：每个索引扫一次表
CREATE INDEX idx1 ON t(col1);  -- 扫表1次，2分钟
CREATE INDEX idx2 ON t(col2);  -- 扫表2次，2分钟
-- 总计4分钟
```

**MySQL 5.7：**
```sql
-- ALTER TABLE：扫表多次，但只加锁1次（推荐）
ALTER TABLE t ADD INDEX idx1(col1), ADD INDEX idx2(col2);

-- CREATE INDEX：扫表多次，加锁多次
CREATE INDEX idx1 ON t(col1);
CREATE INDEX idx2 ON t(col2);
```

---

### Q5: 归档后的备份表需要保留多久？

**建议：**
- 业务重要数据：永久保留（或定期迁移到归档库）
- 日志类数据：保留3-6个月后删除
- 临时数据：验证无误后立即删除

**清理方式：**
```sql
-- 方式1：直接删表
DROP TABLE interfacecenter.t_xapi_log_info_251021bak;

-- 方式2：导出后删除
mysqldump -u root -p interfacecenter t_xapi_log_info_251021bak > backup.sql
DROP TABLE interfacecenter.t_xapi_log_info_251021bak;

-- 方式3：迁移到归档库
CREATE DATABASE archive_db;
RENAME TABLE 
  interfacecenter.t_xapi_log_info_251021bak 
  TO archive_db.t_xapi_log_info_251021bak;
```

---

### Q6: 归档期间主从同步会受影响吗？

**A:** 会有延迟，但不会中断。

```
主库：执行INSERT归档（8分钟）
从库：重放binlog（8分钟 + 网络延迟）

结果：从库延迟8-10分钟，归档完成后自动追上
```

**建议：**
- 低峰期执行归档
- 监控从库延迟：`SHOW SLAVE STATUS\G` 查看 `Seconds_Behind_Master`
- 如果从库有业务查询，考虑先关闭binlog：
  ```sql
  SET SESSION sql_log_bin=0;
  INSERT INTO t_bak SELECT * FROM t;
  SET SESSION sql_log_bin=1;
  ```
  ⚠️ 注意：关闭binlog后从库不会同步该操作

---

### Q7: 归档失败如何回滚？

**场景1：INSERT失败**
```sql
-- 自动回滚，无影响
-- 删除备份表重新执行
DROP TABLE IF EXISTS t_xapi_log_info_bak;
```

**场景2：TRUNCATE误执行**
```sql
-- ❌ TRUNCATE无法回滚！
-- ✅ 从备份表恢复
INSERT INTO t_xapi_log_info SELECT * FROM t_xapi_log_info_bak;
```

**场景3：RENAME失败**
```sql
-- 重新执行RENAME即可
RENAME TABLE 
  t_xapi_log_info_bak TO t_xapi_log_info,
  t_xapi_log_info TO t_xapi_log_info_new;
```

---

## 八、归档前检查清单

### 执行前必查

- [ ] 确认MySQL版本：`SELECT VERSION();`
- [ ] 确认表数据量：`SELECT COUNT(*) FROM t_xapi_log_info;`
- [ ] 确认表大小：
  ```sql
  SELECT 
    ROUND(data_length/1024/1024, 2) AS data_mb,
    ROUND(index_length/1024/1024, 2) AS index_mb,
    ROUND((data_length+index_length)/1024/1024, 2) AS total_mb
  FROM information_schema.tables
  WHERE table_schema='interfacecenter' AND table_name='t_xapi_log_info';
  ```
- [ ] 确认磁盘空间：`df -h`（至少预留2倍表大小）
- [ ] 确认业务低峰期时间
- [ ] 通知相关人员（开发、运维、测试）
- [ ] 准备回滚方案

### 执行中监控

- [ ] 监控锁等待：`SHOW PROCESSLIST;`
- [ ] 监控磁盘IO：`iostat -x 1`
- [ ] 监控从库延迟：`SHOW SLAVE STATUS\G`
- [ ] 监控应用日志（是否有超时报错）

### 执行后验证

- [ ] 验证数据量：
  ```sql
  SELECT COUNT(*) FROM t_xapi_log_info;  -- 应为0（全量归档）
  SELECT COUNT(*) FROM t_xapi_log_info_bak;  -- 应为10000000
  ```
- [ ] 验证表结构：
  ```sql
  SHOW CREATE TABLE t_xapi_log_info_bak;
  ```
- [ ] 验证索引：
  ```sql
  SHOW INDEX FROM t_xapi_log_info_bak;
  ```
- [ ] 验证业务功能（写入、查询）
- [ ] 观察应用日志30分钟

---

## 九、生产执行模板

### 针对t_xapi_log_info的执行脚本

```sql
-- ====================================================================
-- MySQL生产级归档脚本
-- 表名：interfacecenter.t_xapi_log_info
-- 数据量：1000w
-- 执行日期：2024-10-21
-- 执行人：DBA
-- ====================================================================

-- ========== 准备阶段（当天19:00执行） ==========

USE interfacecenter;

-- 1. 备份当前表结构
SHOW CREATE TABLE t_xapi_log_info;

-- 2. 记录当前数据量
SELECT COUNT(*) AS current_count FROM t_xapi_log_info;
-- 预期结果：10000000

-- 3. 记录表大小
SELECT 
  table_name,
  table_rows,
  ROUND(data_length/1024/1024, 2) AS data_mb,
  ROUND(index_length/1024/1024, 2) AS index_mb,
  ROUND((data_length+index_length)/1024/1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema='interfacecenter' AND table_name='t_xapi_log_info';

-- 4. 检查磁盘空间（在Linux执行）
-- df -h

-- 5. 创建空表
CREATE TABLE interfacecenter.t_xapi_log_info_new 
LIKE interfacecenter.t_xapi_log_info;

-- 6. 验证表结构
SHOW CREATE TABLE interfacecenter.t_xapi_log_info_new;

-- 7. 验证索引
SHOW INDEX FROM interfacecenter.t_xapi_log_info_new;


-- ========== 归档阶段（凌晨02:00执行） ==========

-- 1. 再次确认数据量
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info;

-- 2. 执行原子交换（<100ms）
RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_251021bak,
  interfacecenter.t_xapi_log_info_new TO interfacecenter.t_xapi_log_info;

-- 3. 立即验证
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info;  -- 应为0
SELECT COUNT(*) FROM interfacecenter.t_xapi_log_info_251021bak;  -- 应为10000000


-- ========== 验证阶段（归档后立即执行） ==========

-- 1. 验证表结构
SHOW CREATE TABLE interfacecenter.t_xapi_log_info;
SHOW CREATE TABLE interfacecenter.t_xapi_log_info_251021bak;

-- 2. 验证索引
SHOW INDEX FROM interfacecenter.t_xapi_log_info;
SHOW INDEX FROM interfacecenter.t_xapi_log_info_251021bak;

-- 3. 测试写入
INSERT INTO interfacecenter.t_xapi_log_info 
VALUES ('TEST001', 'TEST_API', 'TEST', NULL, NULL, '0', NOW(), NOW(), 'test', 'TEST_SERIAL');

-- 4. 验证写入
SELECT * FROM interfacecenter.t_xapi_log_info WHERE LOG_ID='TEST001';

-- 5. 清理测试数据
DELETE FROM interfacecenter.t_xapi_log_info WHERE LOG_ID='TEST001';

-- 6. 查看表大小
SELECT 
  table_name,
  table_rows,
  ROUND(data_length/1024/1024, 2) AS data_mb,
  ROUND(index_length/1024/1024, 2) AS index_mb,
  ROUND((data_length+index_length)/1024/1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema='interfacecenter' 
  AND table_name IN ('t_xapi_log_info', 't_xapi_log_info_251021bak');


-- ========== 回滚方案（仅在归档失败时执行） ==========

-- 如果归档后发现问题，执行以下回滚
RENAME TABLE 
  interfacecenter.t_xapi_log_info TO interfacecenter.t_xapi_log_info_empty,
  interfacecenter.t_xapi_log_info_251021bak TO interfacecenter.t_xapi_log_info;


-- ========== 清理阶段（3个月后执行） ==========

-- 确认备份表可以删除后
DROP TABLE IF EXISTS interfacecenter.t_xapi_log_info_251021bak;

-- ====================================================================
-- 脚本结束
-- ====================================================================
```

---

## 十、总结与建议

### 针对你的场景（1000w数据日志表）

| 方案 | 推荐度 | 执行时间 | 业务影响 | 备注 |
|------|--------|---------|---------|------|
| **RENAME原子交换** | ⭐⭐⭐⭐⭐ | <1秒 | <100ms | **强烈推荐** |
| 分批归档 | ⭐⭐⭐⭐ | 15-30分钟 | 每批<3秒 | 不能停服时使用 |
| 先插后建索引 | ⭐⭐⭐ | 7-12分钟 | 5-8分钟 | 需维护窗口 |

### 最终建议

**本次归档：**
```sql
-- 2024-10-21 凌晨2:00执行
CREATE TABLE t_xapi_log_info_new LIKE t_xapi_log_info;
RENAME TABLE 
  t_xapi_log_info TO t_xapi_log_info_251021bak,
  t_xapi_log_info_new TO t_xapi_log_info;
```
**执行时间：<1秒  
业务影响：无**

**长期优化：**
- 改造为按月分区表
- 每月自动归档，<5秒完成
- 查询性能提升50%+

---

## 附录：快速参考

### 各版本推荐方案

| MySQL版本 | 全量清空 | 部分归档 | 长期方案 |
|-----------|---------|---------|---------|
| 5.5/5.6 | RENAME | 分批归档 | 定期RENAME |
| 5.7 | RENAME | 分批归档 | 分区表 |
| 8.0 | RENAME ✅ | 先插后索引 | 分区表 ✅ |

### 语法速查

```sql
-- 原子交换
RENAME TABLE t1 TO t1_bak, t1_new TO t1;

-- 一次建多索引
ALTER TABLE t ADD INDEX idx1(col1), ADD INDEX idx2(col2);

-- 分批归档
INSERT INTO t_bak SELECT * FROM t ORDER BY id LIMIT 50000;
DELETE FROM t ORDER BY id LIMIT 50000;

-- 分区表归档
ALTER TABLE t DROP PARTITION p202410;
```

---

**文档版本：** v1.0  
**最后更新：** 2024-10-21  
**适用MySQL：** 5.5 / 5.7 / 8.0










