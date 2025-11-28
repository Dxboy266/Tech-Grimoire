# 二叉搜索树与平衡树详解

## 📚 目录
1. [时间复杂度基础](#时间复杂度基础)
2. [二叉搜索树（BST）](#二叉搜索树bst)
3. [常见树结构对比](#常见树结构对比)
4. [AVL树详解](#avl树详解)
5. [红黑树详解](#红黑树详解)
6. [性质对比与选择建议](#性质对比与选择建议)
7. [最近公共祖先（LCA）](#最近公共祖先lca)

---

## 时间复杂度基础

### log n 和 n log n

**log n（对数时间）**：每次操作将问题规模减半
- log₂(8) = 3，因为 2³ = 8
- log₂(1000) ≈ 10
- log₂(1,000,000) ≈ 20

**直观理解**：猜数字游戏（1-100）
- 最笨方法：从1猜到100，最多100次
- 二分法：每次排除一半，最多 log₂(100) ≈ 7次

**n log n（线性对数时间）**：对n个元素，每个都做log n次操作
- 归并排序：分成log n层，每层处理n个元素
- 1000个元素排序：1000 × 10 = 10,000次操作

### 时间复杂度对比

| 复杂度 | n=1000时操作数 | 典型场景 |
|--------|---------------|---------|
| O(1) | 1 | 数组索引 |
| O(log n) | 10 | 平衡树查找 |
| O(n) | 1,000 | 遍历数组 |
| O(n log n) | 10,000 | 归并排序 |
| O(n²) | 1,000,000 | 冒泡排序 |

---

## 二叉搜索树（BST）

### 定义

对于任意节点：
- 左子树所有节点 < 当前节点
- 右子树所有节点 > 当前节点

```
        5
       / \
      3   7
     / \ / \
    2  4 6  8
```

### 基本操作

**查找**：从根开始比较，小了往左，大了往右
```java
TreeNode search(TreeNode root, int val) {
    if (root == null || root.val == val) return root;
    if (val < root.val) return search(root.left, val);
    return search(root.right, val);
}
```

**插入**：先查找位置，再插入
```java
TreeNode insert(TreeNode root, int val) {
    if (root == null) return new TreeNode(val);
    if (val < root.val) root.left = insert(root.left, val);
    else root.right = insert(root.right, val);
    return root;
}
```

### BST的问题

**最坏情况**：退化成链表，时间复杂度变为O(n)

```
插入序列：1, 2, 3, 4, 5

    1
     \
      2
       \
        3
         \
          4
           \
            5
            
查找5需要5次，不是log n！
```

**解决方案**：自平衡树（AVL树、红黑树）

---

## 常见树结构对比

### 主流树结构

| 树类型 | 平衡条件 | 查找 | 插入 | 删除 | 典型应用 |
|--------|---------|------|------|------|---------|
| **BST** | 无 | O(n) | O(n) | O(n) | 简单场景 |
| **AVL树** | 高度差≤1 | O(log n) | O(log n) | O(log n) | 数据库索引 |
| **红黑树** | 颜色规则 | O(log n) | O(log n) | O(log n) | Java TreeMap/C++ STL |
| **B树** | 多路平衡 | O(log n) | O(log n) | O(log n) | 文件系统/数据库 |
| **B+树** | 叶子有序链 | O(log n) | O(log n) | O(log n) | MySQL索引 |

### 为什么需要平衡树

**目标**：保证树高 = O(log n)，确保操作效率

**方法**：
- AVL树：严格控制高度差
- 红黑树：宽松的平衡条件，减少旋转次数

---

## AVL树详解

### 核心思想

**平衡因子（BF）**：左子树高度 - 右子树高度
- |BF| ≤ 1：平衡
- |BF| > 1：需要旋转调整

```
      5 (BF=0)
     / \
    3   7 (BF=0)
   /     \
  2       8
  
每个节点平衡因子都≤1
```

### 旋转操作

#### 为什么需要旋转？

当插入/删除节点后，某节点的平衡因子变为±2，需要通过旋转重新平衡。

**旋转原理**：
1. 保持BST性质（左<根<右）
2. 降低树高
3. 恢复平衡（|BF|≤1）

#### 右旋（LL情况）

**场景**：左子树的左子树太高（BF=+2）

```
不平衡状态：
        z (BF=+2)
       / \
      y   T4
     / \
    x   T3
    / \
   T1  T2

右旋步骤：
1. y成为新的根
2. z变成y的右子节点
3. T3（y的右子树）变成z的左子树

右旋后：
        y
       / \
      x   z
     / \ / \
    T1 T2 T3 T4
```

**为什么这样旋转？**
- x < y < T3 < z < T4（BST性质保持）
- 树高从3降到2（恢复平衡）

**代码**：
```java
TreeNode rightRotate(TreeNode z) {
    TreeNode y = z.left;
    TreeNode T3 = y.right;
    
    // 执行旋转
    y.right = z;
    z.left = T3;
    
    // 更新高度（从下往上）
    z.height = Math.max(height(z.left), height(z.right)) + 1;
    y.height = Math.max(height(y.left), height(y.right)) + 1;
    
    return y; // 新的根
}
```

#### 左旋（RR情况）

**场景**：右子树的右子树太高（BF=-2）

```
不平衡状态：
    z (BF=-2)
   / \
  T1  y
     / \
    T2  x
       / \
      T3  T4

左旋步骤：
1. y成为新的根
2. z变成y的左子节点
3. T2（y的左子树）变成z的右子树

左旋后：
        y
       / \
      z   x
     / \ / \
    T1 T2 T3 T4
```

**代码**：
```java
TreeNode leftRotate(TreeNode z) {
    TreeNode y = z.right;
    TreeNode T2 = y.left;
    
    y.left = z;
    z.right = T2;
    
    z.height = Math.max(height(z.left), height(z.right)) + 1;
    y.height = Math.max(height(y.left), height(y.right)) + 1;
    
    return y;
}
```

#### 左右旋（LR情况）

**场景**：左子树的右子树太高

```
不平衡：
    z
   / \
  y   T4
 / \
T1  x
   / \
  T2  T3

步骤：
1. 先对y左旋
2. 再对z右旋

结果：
      x
     / \
    y   z
   / \ / \
  T1 T2 T3 T4
```

#### 右左旋（RL情况）

**场景**：右子树的左子树太高

```
不平衡：
  z
 / \
T1  y
   / \
  x   T4
 / \
T2  T3

步骤：
1. 先对y右旋
2. 再对z左旋

结果：
      x
     / \
    z   y
   / \ / \
  T1 T2 T3 T4
```

### AVL树插入完整示例

**插入序列**：10, 5, 15, 2, 7, 12, 20, 1

```
步骤1：插入10
    10

步骤2：插入5
    10
   /
  5

步骤3：插入15
    10
   /  \
  5    15

步骤4：插入2
      10
     /  \
    5    15
   /
  2

步骤5：插入7
      10
     /  \
    5    15
   / \
  2   7

步骤6：插入12
      10
     /  \
    5    15
   / \   /
  2   7 12

步骤7：插入20
      10
     /  \
    5    15
   / \   / \
  2   7 12  20

步骤8：插入1（触发不平衡）
      10 (BF=+2)
     /  \
    5    15
   / \   / \
  2   7 12  20
 /
1

节点5的BF=+1，节点10的BF=+2
检测到LL型不平衡，对节点10右旋

右旋后：
        5
       / \
      2   10
     /   / \
    1   7   15
           / \
          12  20

所有节点BF都≤1，平衡恢复！
```

**旋转判断规则**：
```java
TreeNode insert(TreeNode node, int val) {
    // 1. 标准BST插入
    if (node == null) return new TreeNode(val);
    if (val < node.val) node.left = insert(node.left, val);
    else node.right = insert(node.right, val);
    
    // 2. 更新高度
    node.height = Math.max(height(node.left), height(node.right)) + 1;
    
    // 3. 计算平衡因子
    int balance = getBalance(node);
    
    // 4. 四种情况判断
    // LL：左子树的左子树
    if (balance > 1 && val < node.left.val)
        return rightRotate(node);
    
    // RR：右子树的右子树
    if (balance < -1 && val > node.right.val)
        return leftRotate(node);
    
    // LR：左子树的右子树
    if (balance > 1 && val > node.left.val) {
        node.left = leftRotate(node.left);
        return rightRotate(node);
    }
    
    // RL：右子树的左子树
    if (balance < -1 && val < node.right.val) {
        node.right = rightRotate(node.right);
        return leftRotate(node);
    }
    
    return node;
}
```

### AVL树性质总结

| 性质 | 说明 |
|------|------|
| 平衡条件 | 任意节点左右子树高度差≤1 |
| 树高 | h ≤ 1.44 × log₂(n) |
| 插入旋转 | 最多2次（双旋） |
| 查找速度 | 最快（树最矮） |
| 维护成本 | 高（频繁旋转） |

---

## 红黑树详解

### 五大规则

1. **节点是红色或黑色**
2. **根节点是黑色**
3. **叶子节点（NIL）是黑色**
4. **红色节点的子节点必须是黑色**（不能有连续红色）
5. **从任意节点到叶子节点的所有路径包含相同数量的黑节点**

### 规则5的完整示例

**示例树**：
```
            ⚫10 (黑高=2)
           /    \
         🔴5    🔴15
        /  \    /  \
      ⚫2  ⚫7  ⚫12  ⚫20
```

**路径分析**（从根到NIL）：
```
路径1：⚫10 → 🔴5 → ⚫2 → NIL    黑节点：10, 2 = 2个
路径2：⚫10 → 🔴5 → ⚫7 → NIL    黑节点：10, 7 = 2个
路径3：⚫10 → 🔴15 → ⚫12 → NIL  黑节点：10, 12 = 2个
路径4：⚫10 → 🔴15 → ⚫20 → NIL  黑节点：10, 20 = 2个

✓ 所有路径的黑节点数都是2（黑高度=2）
```

**最长路径≤2×最短路径的证明**：
```
最短路径（全黑）：⚫ → ⚫ → ⚫ (3个节点，黑高=3)
最长路径（黑红交替）：⚫ → 🔴 → ⚫ → 🔴 → ⚫ (5个节点，黑高=3)

5 < 2 × 3 ✓

因为：
- 最短路径只有黑节点，长度 = 黑高度h
- 最长路径黑红交替，长度 = 2h
- 所以最长路径 = 2 × 最短路径
```

### 红黑树插入完整示例

**插入序列**：10, 20, 30, 15

```
步骤1：插入10（根节点，涂黑）
    ⚫10

步骤2：插入20（新节点默认红色）
    ⚫10
      \
      🔴20
      
检查：父节点是黑色，无需调整 ✓

步骤3：插入30
    ⚫10
      \
      🔴20
        \
        🔴30

检查：连续红色（20→30），违反规则4
判断：RR型不平衡
操作：左旋+变色

左旋10节点：
      🔴20
     /   \
   ⚫10   🔴30

但根必须是黑色，20变黑，30可以保持红：
      ⚫20
     /   \
   🔴10   🔴30

检查：✓ 所有规则满足

步骤4：插入15
      ⚫20
     /   \
   🔴10   🔴30
      \
      🔴15

检查：10是红色，15也是红色，违反规则4
判断：LR型不平衡（左子树的右边）
操作：先左旋10，再右旋20，最后变色

先对10左旋：
      ⚫20
     /   \
   🔴15   🔴30
   /
 🔴10

再对20右旋：
      🔴15
     /   \
   🔴10   ⚫20
            \
            🔴30

根节点变黑，调整颜色：
      ⚫15
     /   \
   🔴10   🔴20
            \
            🔴30

但20和30都是红色，违反规则4
20变黑：
      ⚫15
     /   \
   🔴10   ⚫20
            \
            🔴30

最终结果验证：
- ✓ 根节点是黑色
- ✓ 无连续红色
- ✓ 从根到所有NIL的黑高度=2
  * 15→10→NIL: 2个黑
  * 15→20→30→NIL: 2个黑
  * 15→20→NIL: 2个黑
```

### 红黑树插入调整策略

```java
void insertFixup(Node node) {
    // node是新插入的红色节点
    while (node != root && node.parent.color == RED) {
        if (node.parent == node.parent.parent.left) {
            Node uncle = node.parent.parent.right;
            
            // 情况1：叔节点是红色
            if (uncle.color == RED) {
                node.parent.color = BLACK;
                uncle.color = BLACK;
                node.parent.parent.color = RED;
                node = node.parent.parent;
            } else {
                // 情况2：LR型
                if (node == node.parent.right) {
                    node = node.parent;
                    leftRotate(node);
                }
                // 情况3：LL型
                node.parent.color = BLACK;
                node.parent.parent.color = RED;
                rightRotate(node.parent.parent);
            }
        } else {
            // 镜像情况（右侧）
            // ... 类似处理
        }
    }
    root.color = BLACK;
}
```

### 红黑树性质总结

| 性质 | 说明 |
|------|------|
| 平衡条件 | 最长路径≤2×最短路径 |
| 树高 | h ≤ 2 × log₂(n+1) |
| 插入旋转 | 最多2次 |
| 查找速度 | 略慢于AVL |
| 维护成本 | 低（旋转少） |

---

## 性质对比与选择建议

### 详细对比

| 特性 | BST | AVL树 | 红黑树 |
|------|-----|-------|--------|
| 平衡性 | 无 | 严格 | 宽松 |
| 最坏高度 | O(n) | 1.44·log n | 2·log n |
| 查找 | O(n) | O(log n) 最快 | O(log n) |
| 插入 | O(n) | O(log n) 多旋转 | O(log n) 少旋转 |
| 删除 | O(n) | O(log n) 多旋转 | O(log n) 最多3次旋转 |
| 应用场景 | 学习 | 读多写少 | 综合场景 |

### 选择建议

**选AVL树**：
- 查询频繁，插入/删除少
- 对查询速度要求极高
- 数据库索引

**选红黑树**：
- 插入/删除频繁
- 需要整体性能平衡
- Java TreeMap、C++ map/set

**选B/B+树**：
- 磁盘存储
- 数据库系统
- 文件系统

---

## 最近公共祖先（LCA）

### 问题定义

找到同时包含节点p和q的最深节点。

### 递归解法

```java
public TreeNode lowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
    // 递归终止条件
    if (root == null || root == p || root == q) {
        return root;
    }
    
    // 在左右子树中查找
    TreeNode left = lowestCommonAncestor(root.left, p, q);
    TreeNode right = lowestCommonAncestor(root.right, p, q);
    
    // 如果左右都找到，说明p和q分别在两侧，root就是LCA
    if (left != null && right != null) {
        return root;
    }
    
    // 否则返回不为空的一侧
    return left != null ? left : right;
}
```

### 测试用例

#### 用例1：一般情况

```java
/**
 * 树结构：
 *         3
 *       /   \
 *      5     1
 *     / \   / \
 *    6   2 0   8
 *       / \
 *      7   4
 * 
 * 查找：7和4的LCA
 * 结果：2
 */
TreeNode node3 = new TreeNode(3);
TreeNode node5 = new TreeNode(5);
TreeNode node1 = new TreeNode(1);
TreeNode node6 = new TreeNode(6);
TreeNode node2 = new TreeNode(2);
TreeNode node0 = new TreeNode(0);
TreeNode node8 = new TreeNode(8);
TreeNode node7 = new TreeNode(7);
TreeNode node4 = new TreeNode(4);

node3.left = node5;
node3.right = node1;
node5.left = node6;
node5.right = node2;
node2.left = node7;
node2.right = node4;
node1.left = node0;
node1.right = node8;

TreeNode lca = lowestCommonAncestor(node3, node7, node4);
assert lca == node2; // ✓
```

**递归过程**：
```
lowestCommonAncestor(2, 7, 4)
├─ left = lowestCommonAncestor(7, 7, 4) → 返回7
├─ right = lowestCommonAncestor(4, 7, 4) → 返回4
└─ left和right都不为null → 返回2 ✓
```

#### 用例2：一个是另一个的祖先

```java
/**
 * 树结构：
 *        1
 *       / \
 *      2   3
 * 
 * 查找：2和1的LCA
 * 结果：1
 */
TreeNode node1 = new TreeNode(1);
TreeNode node2 = new TreeNode(2);
TreeNode node3 = new TreeNode(3);

node1.left = node2;
node1.right = node3;

TreeNode lca = lowestCommonAncestor(node1, node2, node1);
assert lca == node1; // ✓
```

### 时间复杂度

- **时间**：O(n) - 最坏遍历所有节点
- **空间**：O(h) - 递归栈深度，h为树高

---

## 总结

### 核心要点

1. **BST**：左<根<右，但可能退化
2. **AVL树**：高度严格平衡，查询最快
3. **红黑树**：平衡宽松，插入删除快
4. **选择标准**：读多用AVL，写多用红黑树

### 学习建议

1. 理解平衡因子和颜色规则
2. 掌握四种旋转操作
3. 手画树的变化过程
4. 用代码实现并测试

### 常见面试题

1. 为什么红黑树比AVL树应用广？
   - 插入删除旋转次数少，综合性能好

2. 如何证明红黑树高度是O(log n)？
   - 黑高度h，最短路径h，最长路径2h
   - 黑高度h ≤ log₂(n+1)
   - 总高度 ≤ 2log₂(n+1) = O(log n)

3. AVL树和红黑树的旋转有什么区别？
   - AVL：旋转后更新高度，检查平衡因子
   - 红黑树：旋转后调整颜色，维护颜色规则

---

**文档版本**：v2.0  
**最后更新**：2025-10-27
