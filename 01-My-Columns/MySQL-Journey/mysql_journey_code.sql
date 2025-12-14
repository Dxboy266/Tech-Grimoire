/*
 * MySQL Journey - SQL Summary
 * 专栏：MySQL Journey
 * 描述：本文件汇总了前五讲中涉及的所有SQL代码，方便复习和查阅。
 * 更新时间：2025-12-14
 */

-- ==================================================================
-- 第1讲:入门篇——把MySQL当成Excel来学
-- ==================================================================
-- 本讲主要介绍概念，无具体SQL执行代码。


-- ==================================================================
-- 第2讲:环境搭建与基础操作实战
-- ==================================================================

-- 1. 修改root密码 (Windows/Linux通用)
-- 将 '123456' 替换为你想要的密码
ALTER USER 'root'@'localhost' IDENTIFIED BY '123456';

-- 2. 验证安装，查看版本
SELECT VERSION();

-- 3. 创建数据库
-- IF NOT EXISTS 避免重复创建报错
CREATE DATABASE IF NOT EXISTS company_db;

-- 4. 查看所有数据库
SHOW DATABASES;

-- 5. 使用数据库
USE company_db;

-- 6. 创建员工表 (核心DDL)
-- 包含：自增主键、非空约束、注释、存储引擎、字符集
CREATE TABLE IF NOT EXISTS employee (
    id INT AUTO_INCREMENT PRIMARY KEY COMMENT '员工工号',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    department VARCHAR(30) NOT NULL COMMENT '部门',
    salary DECIMAL(10, 2) NOT NULL COMMENT '薪资', -- 存钱必须用DECIMAL
    hire_date DATE NOT NULL COMMENT '入职时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='员工表';

-- 7. 查看表结构
DESC employee;

-- 8. 插入数据 (DML)
-- 单条插入
INSERT INTO employee (name, department, salary, hire_date) 
VALUES ('张三', '技术部', 8000.00, '2023-01-15');

-- 批量插入 (推荐)
INSERT INTO employee (name, department, salary, hire_date) VALUES
('李四', '市场部', 6000.00, '2023-03-20'),
('王五', '技术部', 9000.00, '2022-11-10'),
('赵六', '人力部', 7000.00, '2023-05-01'),
('孙七', '技术部', 8500.00, '2023-02-14');

-- 9. 基础查询
-- 查询所有
SELECT * FROM employee;
-- 只查特定字段
SELECT name, salary FROM employee;
-- 条件查询
SELECT * FROM employee WHERE department = '技术部';
-- 排序
SELECT * FROM employee ORDER BY salary DESC;
-- 限制数量
SELECT * FROM employee LIMIT 3;

-- 10. 实用技巧：自动更新时间戳的表定义
CREATE TABLE article (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,  -- 创建时自动记录
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP  -- 更新时自动刷新
);

-- 11. DDL常用操作速查
-- ALTER TABLE table_name ADD COLUMN age INT;              -- 添加字段
-- ALTER TABLE table_name MODIFY COLUMN age TINYINT;       -- 修改字段类型
-- ALTER TABLE table_name CHANGE COLUMN age user_age INT;  -- 改字段名+类型
-- ALTER TABLE table_name DROP COLUMN user_age;            -- 删除字段
-- TRUNCATE TABLE table_name;                              -- 清空表数据(保留结构)


-- ==================================================================
-- 第3讲:增删改查实战——搞定80%日常需求
-- ==================================================================

-- 1. INSERT 高级用法
-- INSERT IGNORE: 忽略重复主键报错
INSERT IGNORE INTO employee (id, name, department, salary, hire_date) 
VALUES (1, '张三', '技术部', 8000, '2023-01-15');

-- ON DUPLICATE KEY UPDATE: 存在则更新，不存在则插入
INSERT INTO employee (id, name, department, salary, hire_date) 
VALUES (1, '张三', '技术部', 9000, '2023-01-15')
ON DUPLICATE KEY UPDATE salary = 9000;

-- 2. SELECT 进阶
-- 别名
SELECT name AS 姓名, salary AS 薪资 FROM employee;

-- 复杂条件
SELECT * FROM employee WHERE department = '技术部' AND salary > 8000;
SELECT * FROM employee WHERE salary BETWEEN 7000 AND 9000;
SELECT * FROM employee WHERE department IN ('技术部', '市场部');

-- 模糊查询
SELECT * FROM employee WHERE name LIKE '张%';

-- 空值查询
SELECT * FROM employee WHERE department IS NOT NULL;

-- 分页 (OFFSET)
SELECT * FROM employee LIMIT 3 OFFSET 2;

-- 去重
SELECT DISTINCT department FROM employee;

-- 3. 聚合函数
SELECT COUNT(*) FROM employee;
SELECT SUM(salary) FROM employee WHERE department = '技术部';
SELECT AVG(salary) FROM employee;
SELECT MAX(salary) FROM employee;

-- 4. 分组统计 (GROUP BY & HAVING)
-- 统计各部门人数
SELECT department, COUNT(*) AS 人数
FROM employee
GROUP BY department;

-- 统计平均工资超过8000的部门 (HAVING)
SELECT department, AVG(salary) AS 平均工资
FROM employee
GROUP BY department
HAVING AVG(salary) > 8000;

-- 5. 多表查询 (JOIN)
-- 准备部门表
CREATE TABLE IF NOT EXISTS department (
    id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(30) NOT NULL,
    location VARCHAR(50)
) DEFAULT CHARSET=utf8mb4;

INSERT INTO department (dept_name, location) VALUES
('技术部', '北京'),
('市场部', '上海'),
('人力部', '深圳');

-- INNER JOIN 查询
SELECT e.name, e.salary, d.location
FROM employee e
INNER JOIN department d ON e.department = d.dept_name;

-- 6. UPDATE (安全模式)
-- 先查
SELECT * FROM employee WHERE name = '张三';
-- 再改
UPDATE employee SET salary = 9000 WHERE name = '张三';
-- 批量修改
UPDATE employee SET salary = salary * 1.1 WHERE department = '技术部';

-- 7. DELETE (安全模式)
-- 软删除示例
-- ALTER TABLE employee ADD COLUMN is_deleted TINYINT DEFAULT 0;
-- UPDATE employee SET is_deleted = 1 WHERE id = 5;
-- SELECT * FROM employee WHERE is_deleted = 0;

-- 8. 常用函数案例
-- 查询入职超过1年的员工
SELECT name, hire_date, DATEDIFF(NOW(), hire_date) AS 入职天数
FROM employee
WHERE DATEDIFF(NOW(), hire_date) > 365;

-- 9. 综合案例：查询每个部门工资最高的员工
SELECT e.name, e.department, e.salary
FROM employee e
WHERE e.salary = (
    SELECT MAX(salary) 
    FROM employee 
    WHERE department = e.department
);


-- ==================================================================
-- 第4讲：现代SQL高级特性——窗口函数与CTE
-- ==================================================================

-- 1. 窗口函数：ROW_NUMBER, RANK, DENSE_RANK
-- 场景：每个部门薪资排名
SELECT 
    department,
    name,
    salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS row_num,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_num,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank_num
FROM employee;

-- 场景：取每个部门薪资前3名
SELECT * FROM (
    SELECT 
        department, name, salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employee
) t WHERE rn <= 3;

-- 2. 偏移函数：LAG, LEAD
-- 准备数据
CREATE TABLE IF NOT EXISTS monthly_sales (
    month DATE,
    sales DECIMAL(10,2)
);
INSERT INTO monthly_sales VALUES
('2024-01-01', 10000),
('2024-02-01', 12000),
('2024-03-01', 11000),
('2024-04-01', 15000);

-- 场景：计算环比增长
SELECT 
    month,
    sales,
    LAG(sales, 1) OVER (ORDER BY month) AS last_month_sales,
    sales - LAG(sales, 1) OVER (ORDER BY month) AS month_on_month,
    ROUND((sales - LAG(sales, 1) OVER (ORDER BY month)) / NULLIF(LAG(sales, 1) OVER (ORDER BY month), 0) * 100, 2) AS growth_rate
FROM monthly_sales;

-- 3. 聚合窗口函数
-- 场景：累计销售额
SELECT 
    month,
    sales,
    SUM(sales) OVER (ORDER BY month) AS cumulative_sales
FROM monthly_sales;

-- 场景：3个月移动平均
SELECT 
    month,
    sales,
    AVG(sales) OVER (
        ORDER BY month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3months
FROM monthly_sales;

-- 4. CTE (公共表表达式)
-- 场景：递归CTE查询商品分类树
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

-- 递归查询
WITH RECURSIVE category_tree AS (
    -- 锚点：从手机(id=2)开始
    SELECT id, name, parent_id, 1 AS level
    FROM categories
    WHERE id = 2
    
    UNION ALL
    
    -- 递归：找子节点
    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree;


-- ==================================================================
-- 第5讲：事务——数据一致性的保护伞
-- ==================================================================

-- 1. 准备工作：创建账户表
CREATE TABLE IF NOT EXISTS account (
    id INT PRIMARY KEY AUTO_INCREMENT COMMENT '主键',
    user_id INT NOT NULL COMMENT '用户ID',
    balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT '余额'
) COMMENT '账户表';

INSERT INTO account (user_id, balance) VALUES (1, 1000.00), (2, 0.00);

-- 2. 事务的基本使用
-- 开启事务
START TRANSACTION;

-- 扣款
UPDATE account SET balance = balance - 1000 WHERE user_id = 1;

-- 加款
UPDATE account SET balance = balance + 1000 WHERE user_id = 2;

-- 检查余额 (实际业务逻辑)
SELECT SUM(balance) FROM account WHERE user_id IN (1, 2);

-- 提交事务
COMMIT;

-- 或者回滚
-- ROLLBACK;

-- 3. 隔离级别操作
-- 查看当前隔离级别
SELECT @@transaction_isolation;

-- 设置会话隔离级别 (例如设置为读未提交)
SET SESSION TRANSACTION_ISOLATION = 'READ-UNCOMMITTED';
