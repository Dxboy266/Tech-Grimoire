# 第4讲：现代SQL高级特性——窗口函数与CTE

## 本讲你会学到什么

掌握MySQL 8.0+的核心特性：窗口函数和CTE，这是面试高频考点，也是解决复杂查询的利器。

**核心知识点：**
- 窗口函数：ROW_NUMBER/RANK/LAG/LEAD解决排名、环比等问题
- CTE公共表表达式：提升SQL可读性，替代复杂嵌套子查询
- 递归CTE：查询组织树、分类树等层级数据

**实战产出：** 用现代SQL特性优化复杂查询，代码清晰度提升10倍

---

## 一、为什么需要窗口函数？

### 传统方案的痛点

**需求：** 查询每个部门薪资前3名的员工

**传统方案（关联子查询）：**
```sql
SELECT e1.* 
FROM employee e1
WHERE (
    SELECT COUNT(*) 
    FROM employee e2 
    WHERE e2.department = e1.department 
    AND e2.salary >= e1.salary
) <= 3
ORDER BY department, salary DESC;
```

**问题：**
- SQL嵌套复杂，难以理解
- 性能差：N²的复杂度
- 不灵活：改需求要重写

> 📸 **截图1：** 传统子查询的执行计划（慢）

---

### 窗口函数方案（优雅10倍）

```sql
SELECT * FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employee
) t WHERE rn <= 3;
```

**优势：**
- ✅ 代码清晰，一眼看懂
- ✅ 性能好：O(N log N)
- ✅ 灵活：改需求只需改rn条件

> 📸 **截图2：** 窗口函数的执行计划（快10倍）

---

## 二、窗口函数核心语法

### 语法结构

```sql
<窗口函数> OVER (
    PARTITION BY <分组字段>  -- 类似GROUP BY，但不聚合行
    ORDER BY <排序字段>      -- 组内排序
    ROWS/RANGE <窗口范围>    -- 可选，指定计算范围
)
```

**关键理解：**
- `PARTITION BY`：分组，但不会减少行数
- `ORDER BY`：组内排序
- 窗口函数不能直接在WHERE中使用，需要子查询包裹

---

## 三、排名函数（ROW_NUMBER/RANK/DENSE_RANK）

### 三大排名函数对比

| 函数 | 并列处理 | 示例 | 适用场景 |
|------|---------|------|---------|
| **ROW_NUMBER()** | 连续行号 | 1,2,3,4 | 分页、TopN |
| **RANK()** | 并列跳号 | 1,2,2,4 | 成绩排名(允许并列) |
| **DENSE_RANK()** | 并列不跳号 | 1,2,2,3 | 密集排名 |

### 实战案例

**场景1：每个部门薪资排名**
```sql
SELECT 
    department,
    name,
    salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS row_num,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_num,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank_num
FROM employee;
```

**结果对比：**
```
department | name | salary | row_num | rank_num | dense_rank_num
-----------|------|--------|---------|----------|---------------
技术部     | 张三 | 9000   | 1       | 1        | 1
技术部     | 李四 | 8500   | 2       | 2        | 2
技术部     | 王五 | 8500   | 3       | 2        | 2
技术部     | 赵六 | 8000   | 4       | 4        | 3
```

> 📸 **截图3：** 三种排名函数的对比结果

---

**场景2：每个部门薪资前3名**
```sql
SELECT * FROM (
    SELECT 
        department, name, salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employee
) t WHERE rn <= 3;
```

---

## 四、偏移函数（LAG/LEAD）

### 语法与作用

| 函数 | 作用 | 应用场景 |
|------|------|---------|
| **LAG(字段, N)** | 访问前N行数据 | 计算环比、同比 |
| **LEAD(字段, N)** | 访问后N行数据 | 预测、趋势分析 |

### 实战案例

**场景：计算每月销售额的环比增长**
```sql
-- 假设有月度销售表
CREATE TABLE monthly_sales (
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
    month,
    sales,
    LAG(sales, 1) OVER (ORDER BY month) AS last_month_sales,
    sales - LAG(sales, 1) OVER (ORDER BY month) AS month_on_month,
    ROUND((sales - LAG(sales, 1) OVER (ORDER BY month)) / LAG(sales, 1) OVER (ORDER BY month) * 100, 2) AS growth_rate
FROM monthly_sales;
```

**结果：**
```
month      | sales  | last_month_sales | month_on_month | growth_rate
-----------|--------|------------------|----------------|------------
2024-01-01 | 10000  | NULL             | NULL           | NULL
2024-02-01 | 12000  | 10000            | 2000           | 20.00
2024-03-01 | 11000  | 12000            | -1000          | -8.33
2024-04-01 | 15000  | 11000            | 4000           | 36.36
```

> 📸 **截图4：** LAG函数计算环比增长

---

**场景：查看员工与前一名、后一名的薪资差距**
```sql
SELECT 
    name,
    salary,
    LAG(name, 1) OVER (ORDER BY salary DESC) AS higher_salary_person,
    LAG(salary, 1) OVER (ORDER BY salary DESC) - salary AS gap_with_higher,
    LEAD(name, 1) OVER (ORDER BY salary DESC) AS lower_salary_person,
    salary - LEAD(salary, 1) OVER (ORDER BY salary DESC) AS gap_with_lower
FROM employee;
```

---

## 五、聚合窗口函数（SUM/AVG OVER）

### 累计求和

**场景：计算累计销售额**
```sql
SELECT 
    month,
    sales,
    SUM(sales) OVER (ORDER BY month) AS cumulative_sales
FROM monthly_sales;
```

**结果：**
```
month      | sales  | cumulative_sales
-----------|--------|------------------
2024-01-01 | 10000  | 10000
2024-02-01 | 12000  | 22000
2024-03-01 | 11000  | 33000
2024-04-01 | 15000  | 48000
```

---

### 移动平均

**场景：计算最近3个月的移动平均销售额**
```sql
SELECT 
    month,
    sales,
    AVG(sales) OVER (
        ORDER BY month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3months
FROM monthly_sales;
```

**窗口范围说明：**
- `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`：当前行及前2行（共3行）
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`：从第一行到当前行（累计）

---

## 六、CTE公共表表达式（WITH子句）

### 为什么需要CTE？

**传统子查询：嵌套复杂**
```sql
SELECT dept_name, avg_salary
FROM departments d
JOIN (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
) e ON d.id = e.dept_id
WHERE e.avg_salary > (
    SELECT AVG(salary) FROM employees
);
```

**CTE写法：逻辑清晰**
```sql
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
),
company_avg AS (
    SELECT AVG(salary) AS avg_salary FROM employees
)
SELECT d.dept_name, da.avg_salary
FROM departments d
JOIN dept_avg da ON d.id = da.dept_id
CROSS JOIN company_avg ca
WHERE da.avg_salary > ca.avg_salary;
```

**CTE的优势：**
- ✅ 命名清晰，可读性高
- ✅ 可以多次引用同一个CTE
- ✅ 逻辑分层，便于调试

---

## 七、递归CTE（查询层级数据）

### 语法结构

```sql
WITH RECURSIVE cte_name AS (
    -- 1. 锚点查询（初始数据）
    SELECT ... FROM table WHERE ...
    
    UNION ALL
    
    -- 2. 递归查询（关联上一层结果）
    SELECT ... FROM table JOIN cte_name ON ...
)
SELECT * FROM cte_name;
```

### 实战案例

**场景1：查询员工的所有上级**
```sql
-- 假设员工表有manager_id字段
CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    manager_id INT
);

INSERT INTO employees VALUES
(1, 'CEO', NULL),
(2, 'CTO', 1),
(3, '技术总监', 2),
(4, '张三', 3),
(5, 'CFO', 1),
(6, '财务经理', 5);

-- 查询张三(id=4)的所有上级
WITH RECURSIVE manager_tree AS (
    -- 1. 锚点：从张三开始
    SELECT id, name, manager_id, 1 AS level
    FROM employees
    WHERE id = 4
    
    UNION ALL
    
    -- 2. 递归：查找上级
    SELECT e.id, e.name, e.manager_id, mt.level + 1
    FROM employees e
    JOIN manager_tree mt ON e.id = mt.manager_id
)
SELECT * FROM manager_tree ORDER BY level DESC;
```

**结果：**
```
id | name     | manager_id | level
---|----------|------------|------
1  | CEO      | NULL       | 4
2  | CTO      | 1          | 3
3  | 技术总监 | 2          | 2
4  | 张三     | 3          | 1
```

> 📸 **截图5：** 递归CTE查询组织树

---

**场景2：查询员工的所有下属**
```sql
-- 查询CEO(id=1)的所有下属
WITH RECURSIVE subordinate_tree AS (
    -- 1. 锚点：从CEO开始
    SELECT id, name, manager_id, 1 AS level
    FROM employees
    WHERE id = 1
    
    UNION ALL
    
    -- 2. 递归：查找下属
    SELECT e.id, e.name, e.manager_id, st.level + 1
    FROM employees e
    JOIN subordinate_tree st ON e.manager_id = st.id
)
SELECT * FROM subordinate_tree ORDER BY level, id;
```

---

**场景3：商品分类树**
```sql
-- 商品分类表
CREATE TABLE categories (
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

-- 查询"手机"分类下的所有子分类
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS level
    FROM categories
    WHERE id = 2
    
    UNION ALL
    
    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree;
```

---

## 八、性能对比

### 窗口函数 vs 关联子查询

**测试数据：** 100万行员工数据，10个部门

| 方案 | 执行时间 | SQL行数 |
|------|---------|---------|
| 关联子查询 | 8.5s | 7行（嵌套复杂） |
| **窗口函数** | **0.3s** | **5行（清晰简洁）** |

**性能提升：** 28倍

---

## 九、避坑指南

### 坑1：窗口函数不能直接在WHERE中使用

```sql
-- ❌ 错误
SELECT *, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
FROM employee
WHERE rn <= 3;  -- 报错！

-- ✅ 正确
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
    FROM employee
) t WHERE rn <= 3;
```

---

### 坑2：递归CTE必须有终止条件

```sql
-- ❌ 错误：死循环
WITH RECURSIVE bad_cte AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM bad_cte  -- 永远不会停止
)
SELECT * FROM bad_cte;

-- ✅ 正确：加终止条件
WITH RECURSIVE good_cte AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM good_cte WHERE n < 10  -- 终止条件
)
SELECT * FROM good_cte;
```

---

### 坑3：PARTITION BY不同于GROUP BY

```sql
-- GROUP BY：聚合行，减少行数
SELECT department, COUNT(*) FROM employee GROUP BY department;
-- 结果：3行（3个部门）

-- PARTITION BY：分组计算，不减少行数
SELECT *, COUNT(*) OVER (PARTITION BY department) FROM employee;
-- 结果：10行（所有员工，每行显示所在部门的总人数）
```

---

## 十、本讲作业

### 基础练习
1. 查询每个部门薪资排名前3的员工（用ROW_NUMBER）
2. 计算每个员工的薪资与部门平均薪资的差距（用AVG OVER）
3. 查询每个员工的上一名和下一名（用LAG/LEAD）

### 进阶挑战
4. 用CTE改写一个复杂的嵌套子查询（从你的项目中找）
5. 用递归CTE查询某员工的所有下属（包括下属的下属）
6. 用窗口函数实现分页（替代LIMIT OFFSET）

### 性能对比
7. 对比"每部门TOP3"的两种实现（窗口函数 vs 关联子查询），测试性能差异

---

## 十一、下一讲预告

今天学习了现代SQL的强大特性，下一讲回到MySQL的核心原理。

**第5讲：事务——数据一致性的保护伞**

- 什么是事务？ACID特性是啥？
- 转账的钱怎么保证不丢不重？
- 两个人同时改同一条数据会怎样？
- **隔离级别**：脏读、不可重复读、幻读
- undo log和redo log的作用

掌握了窗口函数和CTE，你的SQL查询能力已经超越了80%的开发者。下一讲我们深入MySQL内核，理解事务和并发控制的原理！

**准备工作：**
- 完成今天的作业，熟练掌握窗口函数
- 思考：两个人同时给同一个账户转账1000元，最后余额应该是多少？

---

**下一讲见！**


