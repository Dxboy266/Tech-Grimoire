/*
 * MySQL Journey - SQL Summary
 * 专栏：MySQL Journey
 * 描述：本文件汇总了专栏中涉及的所有SQL代码，方便复习和查阅。
 * 更新时间：2025-12-28
 */

-- ==================================================================
-- 第1讲:入门篇——把MySQL当成Excel来学
-- ==================================================================
-- 本讲主要介绍概念，无具体SQL执行代码。


-- ==================================================================
-- 第2讲:环境搭建与基础操作实战
-- ==================================================================

-- 1. 修改root密码 (Windows/Linux通用)
ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';

-- 2. 验证安装，查看版本
SELECT VERSION();

-- 3. 创建数据库
CREATE DATABASE IF NOT EXISTS company_db;

-- 4. 查看所有数据库
SHOW DATABASES;

-- 5. 使用数据库
USE company_db;

-- 6. 创建员工表 (核心DDL)
CREATE TABLE IF NOT EXISTS employee (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '员工工号',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    department VARCHAR(30) NOT NULL COMMENT '部门',
    salary DECIMAL(10, 2) NOT NULL COMMENT '薪资',
    hire_date DATE NOT NULL COMMENT '入职时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工表';

-- 7. 查看表结构
DESC employee;

-- 8. 插入数据 (DML)
INSERT INTO employee (name, department, salary, hire_date) 
VALUES ('张三', '技术部', 8000.00, '2023-01-15');

INSERT INTO employee (name, department, salary, hire_date) VALUES
('李四', '市场部', 6000.00, '2023-03-20'),
('王五', '技术部', 9000.00, '2022-11-10'),
('赵六', '人力部', 7000.00, '2023-05-01'),
('孙七', '技术部', 8500.00, '2023-02-14');

-- 9. 基础查询
SELECT * FROM employee;
SELECT name, salary FROM employee;
SELECT * FROM employee WHERE department = '技术部';
SELECT * FROM employee ORDER BY salary DESC;
SELECT * FROM employee LIMIT 3;


-- ==================================================================
-- 第3讲:增删改查实战——搞定80%日常需求
-- ==================================================================

-- 1. INSERT高级用法
INSERT IGNORE INTO employee (id, name, department, salary, hire_date) 
VALUES (1, '张三', '技术部', 8000, '2023-01-15');

INSERT INTO employee (id, name, department, salary, hire_date) 
VALUES (1, '张三', '技术部', 9000, '2023-01-15')
ON DUPLICATE KEY UPDATE salary = 9000;

-- 2. SELECT进阶
SELECT name AS 姓名, salary AS 薪资 FROM employee;
SELECT * FROM employee WHERE department = '技术部' AND salary > 8000;
SELECT * FROM employee WHERE salary BETWEEN 7000 AND 9000;
SELECT * FROM employee WHERE department IN ('技术部', '市场部');
SELECT * FROM employee WHERE name LIKE '张%';
SELECT * FROM employee WHERE department IS NOT NULL;
SELECT * FROM employee LIMIT 3 OFFSET 2;
SELECT DISTINCT department FROM employee;

-- 3. 聚合函数
SELECT COUNT(*) FROM employee;
SELECT SUM(salary) FROM employee WHERE department = '技术部';
SELECT AVG(salary) FROM employee;
SELECT MAX(salary) FROM employee;

-- 4. 分组统计 (GROUP BY & HAVING)
SELECT department, COUNT(*) AS 人数 FROM employee GROUP BY department;
SELECT department, AVG(salary) AS 平均工资 FROM employee GROUP BY department HAVING AVG(salary) > 8000;

-- 5. 多表查询 (JOIN)
CREATE TABLE IF NOT EXISTS department (
    id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(30) NOT NULL,
    location VARCHAR(50)
) DEFAULT CHARSET=utf8mb4;

INSERT INTO department (dept_name, location) VALUES
('技术部', '北京'),
('市场部', '上海'),
('人力部', '深圳');

SELECT e.name, e.salary, d.location
FROM employee e
INNER JOIN department d ON e.department = d.dept_name;

-- 6. UPDATE
UPDATE employee SET salary = 9000 WHERE name = '张三';
UPDATE employee SET salary = salary * 1.1 WHERE department = '技术部';

-- 7. 综合案例：查询每个部门工资最高的员工
SELECT e.name, e.department, e.salary
FROM employee e
WHERE e.salary = (
    SELECT MAX(salary) FROM employee WHERE department = e.department
);


-- ==================================================================
-- 第4讲：现代SQL高级特性——窗口函数与CTE
-- ==================================================================

-- 1. 窗口函数：ROW_NUMBER, RANK, DENSE_RANK
SELECT 
    department, name, salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS row_num,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_num,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank_num
FROM employee;

-- 取每个部门薪资前3名
SELECT * FROM (
    SELECT department, name, salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employee
) t WHERE rn <= 3;

-- 2. 偏移函数：LAG, LEAD
CREATE TABLE IF NOT EXISTS monthly_sales (
    month DATE,
    sales DECIMAL(10,2)
);
INSERT INTO monthly_sales VALUES
('2024-01-01', 10000),
('2024-02-01', 12000),
('2024-03-01', 11000),
('2024-04-01', 15000);

-- 计算环比增长
SELECT 
    month, sales,
    LAG(sales, 1) OVER (ORDER BY month) AS last_month_sales,
    sales - LAG(sales, 1) OVER (ORDER BY month) AS month_on_month,
    ROUND((sales - LAG(sales, 1) OVER (ORDER BY month)) / NULLIF(LAG(sales, 1) OVER (ORDER BY month), 0) * 100, 2) AS growth_rate
FROM monthly_sales;

-- 3. 聚合窗口函数：累计销售额
SELECT month, sales, SUM(sales) OVER (ORDER BY month) AS cumulative_sales
FROM monthly_sales;

-- 3个月移动平均
SELECT month, sales,
    AVG(sales) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3months
FROM monthly_sales;

-- 4. CTE递归查询
CREATE TABLE IF NOT EXISTS categories (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    parent_id INT
);
INSERT INTO categories VALUES
(1, '电子产品', NULL),
(2, '手机', 1),
(3, '电脑', 1),
(4, 'iPhone', 2),
(5, 'Android', 2),
(6, '笔记本', 3),
(7, '台式机', 3);

WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS level FROM categories WHERE id = 2
    UNION ALL
    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree;


-- ==================================================================
-- 第5讲：事务——数据一致性的保护伞
-- ==================================================================

-- 1. 创建账户表
CREATE TABLE IF NOT EXISTS account (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    user_id INT NOT NULL COMMENT '用户ID',
    balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT '余额'
) COMMENT '账户表';
INSERT INTO account (user_id, balance) VALUES (1, 1000.00), (2, 0.00);

-- 2. 事务的基本使用
START TRANSACTION;
UPDATE account SET balance = balance - 1000 WHERE user_id = 1;
UPDATE account SET balance = balance + 1000 WHERE user_id = 2;
SELECT SUM(balance) FROM account WHERE user_id IN (1, 2);
COMMIT;
-- ROLLBACK;

-- 3. 隔离级别操作
SELECT @@transaction_isolation;
SET SESSION TRANSACTION_ISOLATION = 'READ-UNCOMMITTED';


-- ==================================================================
-- 第6讲：索引（上）——B+树与查询加速原理
-- ==================================================================

-- 1. 创建订单表
CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
  user_id BIGINT NOT NULL COMMENT '用户ID',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '订单状态：0待支付 1已支付 2已完成',
  amount DECIMAL(10,2) NOT NULL COMMENT '订单金额',
  created_at DATETIME NOT NULL COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- 2. 插入测试数据
INSERT INTO orders(user_id, status, amount, created_at) VALUES
(10001, 1, 99.99, '2025-12-25 10:30:00'),
(10001, 2, 199.99, '2025-12-25 14:20:00'),
(10001, 0, 99.99, '2025-12-24 09:15:00');

-- 3. 创建索引
CREATE INDEX idx_user_id ON orders(user_id);
CREATE INDEX idx_created_at ON orders(created_at);

-- 4. 查看索引
SHOW INDEX FROM orders;

-- 5. 联合索引
CREATE INDEX idx_user_status ON orders(user_id, status);
CREATE INDEX idx_user_status_time ON orders(user_id, status, created_at);

-- 6. 查看字段区分度
SELECT 
  COUNT(DISTINCT user_id) / COUNT(*) AS user_id区分度,
  COUNT(DISTINCT status) / COUNT(*) AS status区分度
FROM orders;


-- ==================================================================
-- 第7讲：索引（下）——失效场景与优化实战
-- ==================================================================

-- 1. 重建orders表（用于1000万数据测试）
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '订单ID',
  user_id BIGINT NOT NULL COMMENT '用户ID',
  status TINYINT NOT NULL DEFAULT 0 COMMENT '订单状态：0待支付 1已支付 2已完成',
  amount DECIMAL(10,2) NOT NULL COMMENT '订单金额',
  created_at DATETIME NOT NULL COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

-- 2. 导入1000万数据（使用LOAD DATA）
LOAD DATA LOCAL INFILE 'D:/path/to/orders_data.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
(user_id, status, amount, created_at);

-- 3. 验证导入结果
SELECT COUNT(*) FROM orders;

-- 4. 创建业务索引
ALTER TABLE orders ADD INDEX idx_user_id(user_id);
ALTER TABLE orders ADD INDEX idx_created_at(created_at);
SHOW INDEX FROM orders;

-- 5. EXPLAIN基本用法
EXPLAIN SELECT * FROM orders WHERE user_id = 10001;

-- 6. 三种场景对比
-- 全表扫描
EXPLAIN SELECT * FROM orders WHERE status = 0;
-- 使用索引
EXPLAIN SELECT * FROM orders WHERE user_id = 10001;
-- 覆盖索引
CREATE INDEX idx_user_status ON orders(user_id, status);
EXPLAIN SELECT user_id, status FROM orders WHERE user_id = 10001;

-- 7. 实战案例：查询某天订单
-- 错误写法（函数导致索引失效）
EXPLAIN SELECT * FROM orders WHERE DATE(created_at) = '2025-06-15';
-- 正确写法（范围查询）
EXPLAIN SELECT * FROM orders 
WHERE created_at >= '2025-06-15 00:00:00' AND created_at < '2025-06-16 00:00:00';
-- 覆盖索引优化
CREATE INDEX idx_created_user_status ON orders(created_at, user_id, status);
EXPLAIN SELECT created_at, user_id, status FROM orders
WHERE created_at >= '2025-06-15 00:00:00' AND created_at < '2025-06-16 00:00:00';

-- 8. 索引失效场景演示
-- 场景1：函数导致失效
EXPLAIN SELECT * FROM orders WHERE YEAR(created_at) = 2025;
EXPLAIN SELECT * FROM orders WHERE created_at >= '2025-01-01' AND created_at < '2026-01-01';

-- 场景2：隐式类型转换（用employee表的name字段演示）
EXPLAIN SELECT * FROM employee WHERE name = 123;

-- 场景3：违反最左匹配
EXPLAIN SELECT * FROM orders WHERE status = 0;

-- 场景6：不等于操作符
EXPLAIN SELECT * FROM orders WHERE status != 0;
EXPLAIN SELECT * FROM orders WHERE status IN (1, 2);

-- 9. 慢查询日志
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SHOW VARIABLES LIKE 'slow_query_log_file';

-- 10. 更新统计信息
ANALYZE TABLE orders;
