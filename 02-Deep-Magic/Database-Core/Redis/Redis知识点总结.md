# Redis 知识点总结 - 从入门到精通

> 本文档基于实战项目经验，系统总结Redis核心知识点，涵盖基础、进阶、高级内容，适合面试复习和技术沉淀。

---

## 目录

- [第一部分：Redis基础入门](#第一部分redis基础入门)
- [第二部分：Redis持久化机制](#第二部分redis持久化机制)
- [第三部分：Redis内存管理](#第三部分redis内存管理)
- [第四部分：Redis缓存问题与解决方案](#第四部分redis缓存问题与解决方案)
- [第五部分：Redis高可用架构](#第五部分redis高可用架构)
- [第六部分：Redis高级特性](#第六部分redis高级特性)
- [第七部分：Redis性能优化](#第七部分redis性能优化)
- [第八部分：大厂高频面试题50道](#第八部分大厂高频面试题50道)

---

## 第一部分：Redis基础入门

### 1.1 Redis简介

**Redis**（Remote Dictionary Server）是一个开源的内存数据库，使用C语言编写。它的数据存储在内存中，因此读写速度非常快，被广泛应用于缓存、消息队列、分布式锁等场景。

**核心特点**：
- **高性能**：基于内存操作，读写速度快（单机QPS可达10w+）
- **丰富的数据类型**：支持String、Hash、List、Set、ZSet等多种数据结构
- **持久化**：支持RDB和AOF两种持久化方式
- **高可用**：支持主从复制、哨兵模式、集群模式
- **原子性**：所有操作都是原子性的

**应用场景**：
1. **缓存**：减轻数据库压力，提升系统性能
2. **Session分离**：分布式环境下的会话管理
3. **分布式锁**：保证分布式系统的数据一致性
4. **消息队列**：List实现简单的消息队列
5. **排行榜**：ZSet实现实时排行榜
6. **计数器**：String的INCR命令实现原子计数
7. **签到打卡**：Bitmap实现用户签到统计

### 1.2 Redis数据类型

#### 1.2.1 String（字符串）

**特点**：
- 最基本的数据类型，最大512MB
- 底层实现：SDS（Simple Dynamic String，简单动态字符串）
- 相比C字符串，SDS不会造成缓冲区溢出，获取长度复杂度O(1)

**常用命令**：
```bash
SET key value          # 设置值
GET key                # 获取值
INCR key               # 原子递增
DECR key               # 原子递减
SETEX key seconds value # 设置值并指定过期时间
SETNX key value        # 仅当key不存在时设置（分布式锁）
```

**应用场景**：
- 缓存对象：`SET user:1001 '{"name":"张三","age":25}'`
- 计数器：`INCR article:readcount:101`（文章阅读数）
- 分布式锁：`SETNX lock:order:1001 true`

#### 1.2.2 Hash（哈希表）

**特点**：
- 类似Java的HashMap，存储键值对集合
- 适合存储对象，可以只修改某个字段

**常用命令**：
```bash
HSET key field value   # 设置字段值
HGET key field         # 获取字段值
HMSET key f1 v1 f2 v2  # 批量设置
HGETALL key            # 获取所有字段和值
HINCRBY key field num  # 字段值增加
```

**应用场景**：
- 用户信息：`HSET user:1001 name "张三" age 25 city "北京"`
- 购物车：`HSET cart:1001 product:10001 2 product:10002 1`

#### 1.2.3 List（列表）

**特点**：
- 双向链表，支持从两端插入和删除
- 适合存储有序列表

**常用命令**：
```bash
LPUSH key value        # 左侧插入
RPUSH key value        # 右侧插入
LPOP key               # 左侧弹出
RPOP key               # 右侧弹出
LRANGE key start stop  # 获取范围元素
BLPOP key timeout      # 阻塞式左侧弹出（消息队列）
```

**应用场景**：
- 消息队列：`LPUSH + BRPOP` 实现阻塞队列
- 最新列表：`LPUSH msg:list` + `LRANGE msg:list 0 9`（最新10条消息）
- 关注列表：`LPUSH follows:1001 user:2001`

#### 1.2.4 Set（集合）

**特点**：
- 无序、不重复的字符串集合
- 支持集合运算（交集、并集、差集）

**常用命令**：
```bash
SADD key member        # 添加元素
SREM key member        # 删除元素
SMEMBERS key           # 获取所有元素
SISMEMBER key member   # 判断元素是否存在
SINTER key1 key2       # 交集
SUNION key1 key2       # 并集
SDIFF key1 key2        # 差集
```

**应用场景**：
- 标签系统：`SADD user:1001:tags "Java" "Redis" "MySQL"`
- 共同关注：`SINTER follows:1001 follows:1002`
- 抽奖系统：`SRANDMEMBER lottery:20240101 10`（随机抽取10个中奖者）

#### 1.2.5 ZSet（有序集合）

**特点**：
- 有序、不重复的字符串集合
- 每个元素关联一个分数（score），按分数排序
- 底层实现：跳跃表（Skip List）+ 哈希表

**常用命令**：
```bash
ZADD key score member  # 添加元素
ZRANGE key start stop  # 按分数升序获取
ZREVRANGE key start stop # 按分数降序获取
ZINCRBY key num member # 增加分数
ZRANK key member       # 获取排名
```

**应用场景**：
- 排行榜：`ZADD rank:2024 1000 "user:1001"`
- 延迟队列：以时间戳为score，定时取出到期任务
- 热搜榜：`ZINCRBY hotsearch:20240101 1 "Redis"`

#### 1.2.6 高级数据类型

**Bitmap（位图）**：
- 用bit位存储0/1状态，节省空间
- 应用：用户签到、在线状态、布隆过滤器
```bash
SETBIT sign:1001:202401 0 1  # 1月1日签到
GETBIT sign:1001:202401 0    # 查询1月1日是否签到
BITCOUNT sign:1001:202401    # 统计1月签到天数
```

**HyperLogLog**：
- 基数统计，占用空间小（12KB）
- 应用：UV统计、独立IP统计
```bash
PFADD uv:20240101 "user1" "user2"
PFCOUNT uv:20240101  # 统计UV
```

**Geo（地理位置）**：
- 存储地理位置信息
- 应用：附近的人、外卖配送
```bash
GEOADD locations 116.40 39.90 "北京"
GEORADIUS locations 116.40 39.90 100 km  # 查询100km内的位置
```

### 1.3 Key设计规范

**命名规范**：
1. **可读性**：使用业务名作为前缀，用冒号分隔
   - ✅ 推荐：`user:1001:info`、`order:2024:1001`
   - ❌ 不推荐：`u1001`、`o20241001`

2. **简洁性**：在保证语义的前提下，控制key长度
   - ✅ 推荐：`u:1001:fr:m:1001`
   - ❌ 不推荐：`user:1001:friends:messages:1001`

3. **避免特殊字符**：不要包含空格、换行、引号等

**避免BigKey**：
- String类型：单个value < 10KB
- 集合类型：元素个数 < 1万

**过期时间**：
- 为key设置合理的过期时间，避免内存浪费
- 使用随机过期时间，防止缓存雪崩

---

## 第二部分：Redis持久化机制

Redis是内存数据库，为了避免数据丢失，提供了两种持久化方式：**RDB**和**AOF**。

### 2.1 RDB持久化（Redis DataBase）

#### 2.1.1 概念

RDB持久化是将某个时间点的内存快照（Snapshot）保存到磁盘的RDB文件中。

#### 2.1.2 触发机制

**手动触发**：
1. **SAVE命令**：阻塞Redis服务器，直到RDB文件创建完成（生产环境禁用）
2. **BGSAVE命令**：fork子进程执行持久化，主进程继续处理请求

**自动触发**：
配置`redis.conf`中的save规则：
```bash
save 900 1      # 900秒内至少1次写操作
save 300 10     # 300秒内至少10次写操作
save 60 10000   # 60秒内至少10000次写操作
```

其他触发场景：
- 执行`SHUTDOWN`命令时
- 主从复制时，主节点自动执行BGSAVE
- 执行`FLUSHALL`命令时

#### 2.1.3 工作原理

1. Redis调用fork()创建子进程
2. 子进程将内存数据写入临时RDB文件
3. 写入完成后，用临时文件替换旧的RDB文件
4. 子进程退出

**关键技术：Copy-On-Write（写时复制）**
- fork后，父子进程共享内存页
- 当父进程修改数据时，才复制该内存页
- 减少内存占用，提高fork效率

#### 2.1.4 配置参数

```bash
# RDB文件名
dbfilename dump.rdb

# RDB文件保存路径
dir /var/lib/redis/

# 持久化失败时，是否停止写入
stop-writes-on-bgsave-error yes

# 是否压缩RDB文件（LZF算法）
rdbcompression yes

# 是否校验RDB文件
rdbchecksum yes
```

#### 2.1.5 优缺点

**优点**：
- ✅ 文件紧凑，适合备份和灾难恢复
- ✅ 恢复速度快（直接加载到内存）
- ✅ 性能高（fork子进程，不影响主进程）

**缺点**：
- ❌ 数据完整性差（可能丢失最后一次快照后的数据）
- ❌ fork子进程耗时，数据量大时可能阻塞主进程
- ❌ 不适合实时持久化

### 2.2 AOF持久化（Append Only File）

#### 2.2.1 概念

AOF持久化以日志的形式记录每个写操作，Redis重启时重新执行AOF文件中的命令来恢复数据。

#### 2.2.2 开启AOF

```bash
# 开启AOF
appendonly yes

# AOF文件名
appendfilename "appendonly.aof"

# AOF文件保存路径（与RDB相同）
dir /var/lib/redis/
```

#### 2.2.3 工作原理

**三个步骤**：
1. **命令追加（Append）**：将写命令追加到AOF缓冲区
2. **文件写入（Write）**：将AOF缓冲区内容写入AOF文件
3. **文件同步（Sync）**：将AOF文件同步到磁盘

#### 2.2.4 同步策略

Redis提供3种AOF同步策略：

```bash
# 同步策略配置
appendfsync always    # 每次写操作都同步（最安全，性能最差）
appendfsync everysec  # 每秒同步一次（推荐，平衡性能和安全）
appendfsync no        # 由操作系统决定何时同步（性能最好，安全性最差）
```

**选择建议**：
- **always**：适合对数据安全性要求极高的场景（金融系统）
- **everysec**：推荐使用，最多丢失1秒数据
- **no**：不推荐，可能丢失大量数据

#### 2.2.5 AOF重写机制

**问题**：AOF文件会越来越大，影响性能

**解决**：AOF重写（Rewrite）

**原理**：
- 不是读取旧AOF文件，而是直接读取当前内存数据
- 用一条命令代替多条命令（如：100次INCR → 1次SET）

**触发方式**：

1. **手动触发**：`BGREWRITEAOF`命令

2. **自动触发**：配置参数
```bash
# 当前AOF文件大小是上次重写后的100%时触发
auto-aof-rewrite-percentage 100

# AOF文件至少达到64MB时才触发重写
auto-aof-rewrite-min-size 64mb
```

**重写流程**：
1. Redis fork子进程执行重写
2. 子进程读取内存数据，写入新AOF文件
3. 主进程继续处理请求，新写操作追加到AOF重写缓冲区
4. 子进程完成后，主进程将AOF重写缓冲区内容追加到新AOF文件
5. 用新AOF文件替换旧文件

#### 2.2.6 优缺点

**优点**：
- ✅ 数据完整性好（最多丢失1秒数据）
- ✅ AOF文件可读性强（文本格式）
- ✅ 支持AOF重写，控制文件大小

**缺点**：
- ❌ AOF文件比RDB文件大
- ❌ 恢复速度慢（需要重新执行命令）
- ❌ 性能略低于RDB

### 2.3 混合持久化（Redis 4.0+）

**概念**：结合RDB和AOF的优点

**原理**：
- AOF重写时，将重写时刻的内存快照以RDB格式写入AOF文件开头
- 后续的写操作以AOF格式追加到文件末尾

**开启方式**：
```bash
aof-use-rdb-preamble yes
```

**优点**：
- ✅ 恢复速度快（RDB部分直接加载）
- ✅ 数据完整性好（AOF部分保证最新数据）

### 2.4 持久化策略选择

**场景一：缓存场景**
- 数据可以从数据库重新加载
- 建议：关闭持久化或只开启RDB

**场景二：数据重要但可接受少量丢失**
- 建议：开启RDB（save 900 1）

**场景三：数据非常重要，不能丢失**
- 建议：开启AOF（appendfsync everysec）+ RDB备份

**场景四：高性能要求**
- 建议：开启混合持久化

**生产环境最佳实践**：
```bash
# 同时开启RDB和AOF
save 900 1
save 300 10
save 60 10000

appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes

# 定期备份RDB文件到远程服务器
```

---

## 第三部分：Redis内存管理

### 3.1 过期删除策略

Redis的过期删除策略采用**惰性删除 + 定期删除**组合方式。

#### 3.1.1 惰性删除（Lazy Expiration）

**原理**：
- 当访问一个key时，才检查该key是否过期
- 如果过期，删除该key并返回nil
- 如果未过期，返回value

**优点**：
- ✅ 对CPU友好，只在访问时才检查

**缺点**：
- ❌ 对内存不友好，过期key可能长期占用内存

**实现**：
- 所有读写命令执行前都会调用`expireIfNeeded`函数

#### 3.1.2 定期删除（Active Expiration）

**原理**：
- Redis定期随机抽取一些设置了过期时间的key进行检查
- 如果过期，删除该key
- 默认每秒执行10次（可通过`hz`参数配置）

**算法**：
1. 随机抽取20个（`ACTIVE_EXPIRE_CYCLE_LOOKUPS_PER_LOOP`）设置了过期时间的key
2. 删除其中所有过期的key
3. 如果过期key比例超过25%，重复步骤1
4. 如果过期key比例低于25%，停止检查

**优点**：
- ✅ 限制删除操作的执行时长和频率，减少对CPU的影响
- ✅ 及时清理过期key，释放内存

**缺点**：
- ❌ 难以确定删除操作的执行时长和频率

#### 3.1.3 设置过期时间

```bash
# 设置过期时间（秒）
EXPIRE key seconds
EXPIREAT key timestamp

# 设置过期时间（毫秒）
PEXPIRE key milliseconds
PEXPIREAT key milliseconds-timestamp

# 查看剩余时间
TTL key        # 秒
PTTL key       # 毫秒

# 移除过期时间
PERSIST key
```

### 3.2 内存淘汰策略

当Redis内存达到`maxmemory`限制时，会触发内存淘汰策略。

#### 3.2.1 配置maxmemory

```bash
# 设置最大内存（字节）
maxmemory 1gb

# 设置内存淘汰策略
maxmemory-policy allkeys-lru
```

#### 3.2.2 8种淘汰策略

**针对设置了过期时间的key**：
1. **volatile-lru**：使用LRU算法淘汰
2. **volatile-lfu**：使用LFU算法淘汰（Redis 4.0+）
3. **volatile-random**：随机淘汰
4. **volatile-ttl**：淘汰即将过期的key（TTL最小的）

**针对所有key**：
5. **allkeys-lru**：使用LRU算法淘汰（推荐）
6. **allkeys-lfu**：使用LFU算法淘汰（Redis 4.0+）
7. **allkeys-random**：随机淘汰

**不淘汰**：
8. **noeviction**：不淘汰，内存满时拒绝写入（默认策略）

#### 3.2.3 LRU算法（Least Recently Used）

**原理**：淘汰最近最少使用的数据

**Redis实现**：
- 不是严格的LRU，而是近似LRU
- 随机采样N个key（默认5个），淘汰其中最久未使用的
- 采样数量可通过`maxmemory-samples`配置

**优点**：
- ✅ 实现简单，性能高
- ✅ 适合大多数场景

**缺点**：
- ❌ 可能淘汰热点数据（偶尔未访问）

#### 3.2.4 LFU算法（Least Frequently Used）

**原理**：淘汰访问频率最低的数据

**Redis实现**：
- 使用24bit的lru字段：
  - 前16bit：最后访问时间戳（分钟级）
  - 后8bit：访问次数计数器（对数计数器）

**优点**：
- ✅ 更准确反映数据热度
- ✅ 不会因偶尔未访问而淘汰热点数据

**缺点**：
- ❌ 实现复杂，性能略低

#### 3.2.5 淘汰策略选择

**场景一：纯缓存场景**
- 建议：`allkeys-lru` 或 `allkeys-lfu`
- 原因：所有key都可能被淘汰

**场景二：部分数据需要持久化**
- 建议：`volatile-lru` 或 `volatile-lfu`
- 原因：只淘汰设置了过期时间的key

**场景三：不允许数据丢失**
- 建议：`noeviction`
- 原因：内存满时拒绝写入，通过监控及时扩容

**生产环境推荐**：
```bash
maxmemory 4gb
maxmemory-policy allkeys-lru
maxmemory-samples 10  # 增加采样数量，提高准确性
```

### 3.3 内存优化建议

1. **控制key长度**：使用短key，节省内存
2. **选择合适的数据类型**：如用Hash代替String存储对象
3. **开启压缩**：
   ```bash
   # 压缩列表配置
   hash-max-ziplist-entries 512
   hash-max-ziplist-value 64
   ```
4. **设置过期时间**：及时清理无用数据
5. **避免BigKey**：拆分大key为多个小key
6. **定期清理**：使用`SCAN`命令扫描并清理无用key

---

## 第四部分：Redis缓存问题与解决方案

### 4.1 缓存穿透

#### 4.1.1 问题描述

**定义**：查询一个不存在的数据，缓存和数据库都没有，导致每次请求都打到数据库。

**场景**：
- 恶意攻击：故意查询不存在的数据（如ID=-1）
- 业务逻辑漏洞：前端未校验参数

**危害**：
- 数据库压力激增
- 可能导致数据库宕机

#### 4.1.2 解决方案

**方案一：缓存空值**

```java
public User getUser(Long userId) {
    // 1. 查询缓存
    String cacheKey = "user:" + userId;
    User user = redisTemplate.opsForValue().get(cacheKey);
    
    if (user != null) {
        return user;
    }
    
    // 2. 查询数据库
    user = userMapper.selectById(userId);
    
    if (user != null) {
        // 3. 存入缓存（正常过期时间）
        redisTemplate.opsForValue().set(cacheKey, user, 1, TimeUnit.HOURS);
    } else {
        // 4. 缓存空值（短过期时间）
        redisTemplate.opsForValue().set(cacheKey, new User(), 5, TimeUnit.MINUTES);
    }
    
    return user;
}
```

**优点**：
- ✅ 实现简单

**缺点**：
- ❌ 占用额外内存
- ❌ 可能造成短期数据不一致

**方案二：布隆过滤器（推荐）**

```java
@Component
public class UserService {
    
    @Autowired
    private RedissonClient redissonClient;
    
    private RBloomFilter<Long> userBloomFilter;
    
    @PostConstruct
    public void init() {
        // 初始化布隆过滤器
        userBloomFilter = redissonClient.getBloomFilter("user:bloom");
        userBloomFilter.tryInit(10000000L, 0.01); // 预计1000万用户，误判率1%
        
        // 将所有用户ID加入布隆过滤器
        List<Long> userIds = userMapper.selectAllIds();
        userIds.forEach(userBloomFilter::add);
    }
    
    public User getUser(Long userId) {
        // 1. 布隆过滤器判断
        if (!userBloomFilter.contains(userId)) {
            return null; // 一定不存在
        }
        
        // 2. 查询缓存
        String cacheKey = "user:" + userId;
        User user = redisTemplate.opsForValue().get(cacheKey);
        if (user != null) {
            return user;
        }
        
        // 3. 查询数据库
        user = userMapper.selectById(userId);
        if (user != null) {
            redisTemplate.opsForValue().set(cacheKey, user, 1, TimeUnit.HOURS);
        }
        
        return user;
    }
}
```

**优点**：
- ✅ 内存占用小（1000万数据约12MB）
- ✅ 查询速度快（O(k)，k为哈希函数个数）

**缺点**：
- ❌ 存在误判率（可通过增加内存降低）
- ❌ 不支持删除（可使用Counting Bloom Filter）

**方案三：接口层校验**

```java
@RestController
public class UserController {
    
    @GetMapping("/user/{userId}")
    public User getUser(@PathVariable Long userId) {
        // 参数校验
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("用户ID非法");
        }
        
        return userService.getUser(userId);
    }
}
```

### 4.2 缓存击穿

#### 4.2.1 问题描述

**定义**：一个热点key过期的瞬间，大量请求同时访问该key，导致请求全部打到数据库。

**场景**：
- 热点数据过期（如秒杀商品）
- 缓存重启后，热点数据未预热

**危害**：
- 数据库瞬时压力激增
- 可能导致数据库宕机

#### 4.2.2 解决方案

**方案一：互斥锁**

```java
public User getUser(Long userId) {
    String cacheKey = "user:" + userId;
    String lockKey = "lock:user:" + userId;
    
    // 1. 查询缓存
    User user = redisTemplate.opsForValue().get(cacheKey);
    if (user != null) {
        return user;
    }
    
    // 2. 获取分布式锁
    Boolean lock = redisTemplate.opsForValue().setIfAbsent(lockKey, "1", 10, TimeUnit.SECONDS);
    
    if (lock) {
        try {
            // 3. 双重检查
            user = redisTemplate.opsForValue().get(cacheKey);
            if (user != null) {
                return user;
            }
            
            // 4. 查询数据库
            user = userMapper.selectById(userId);
            
            // 5. 写入缓存
            if (user != null) {
                redisTemplate.opsForValue().set(cacheKey, user, 1, TimeUnit.HOURS);
            }
            
            return user;
        } finally {
            // 6. 释放锁
            redisTemplate.delete(lockKey);
        }
    } else {
        // 7. 未获取到锁，等待后重试
        try {
            Thread.sleep(50);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return getUser(userId);
    }
}
```

**优点**：
- ✅ 保证只有一个线程查询数据库
- ✅ 数据一致性强

**缺点**：
- ❌ 性能略低（需要等待锁）
- ❌ 实现复杂

**方案二：热点数据永不过期**

```java
public User getUser(Long userId) {
    String cacheKey = "user:" + userId;
    
    // 1. 查询缓存（不设置过期时间）
    User user = redisTemplate.opsForValue().get(cacheKey);
    
    if (user == null) {
        // 2. 查询数据库
        user = userMapper.selectById(userId);
        
        // 3. 写入缓存（不设置过期时间）
        if (user != null) {
            redisTemplate.opsForValue().set(cacheKey, user);
        }
    }
    
    return user;
}

// 异步更新缓存
@Scheduled(fixedRate = 3600000) // 每小时执行一次
public void refreshHotData() {
    List<Long> hotUserIds = getHotUserIds(); // 获取热点用户ID
    for (Long userId : hotUserIds) {
        User user = userMapper.selectById(userId);
        if (user != null) {
            redisTemplate.opsForValue().set("user:" + userId, user);
        }
    }
}
```

**优点**：
- ✅ 性能高，无需等待
- ✅ 实现简单

**缺点**：
- ❌ 占用内存
- ❌ 数据可能不是最新的

### 4.3 缓存雪崩

#### 4.3.1 问题描述

**定义**：大量缓存同时过期或Redis宕机，导致大量请求打到数据库。

**场景**：
- 批量设置相同的过期时间
- Redis服务器宕机
- 缓存重启

**危害**：
- 数据库压力激增
- 可能导致整个系统崩溃

#### 4.3.2 解决方案

**方案一：过期时间随机偏移（推荐）**

```java
public void setCache(String key, Object value, long baseExpire) {
    // 基础过期时间 + 随机偏移（0-10分钟）
    long randomExpire = ThreadLocalRandom.current().nextInt(600);
    long expire = baseExpire + randomExpire;
    
    redisTemplate.opsForValue().set(key, value, expire, TimeUnit.SECONDS);
}

// 使用示例
setCache("user:1001", user, 3600); // 1小时 + 随机0-10分钟
```

**优点**：
- ✅ 实现简单
- ✅ 有效避免大量key同时过期

**方案二：缓存预热**

```java
@Component
public class CacheWarmUp {
    
    @PostConstruct
    public void init() {
        // 系统启动时，预热热点数据
        List<User> hotUsers = userMapper.selectHotUsers();
        for (User user : hotUsers) {
            String cacheKey = "user:" + user.getId();
            redisTemplate.opsForValue().set(cacheKey, user, 1, TimeUnit.HOURS);
        }
    }
}
```

**方案三：Redis高可用**

- 使用Redis Cluster或哨兵模式
- 主节点宕机时，自动切换到从节点

**方案四：降级策略**

```java
public User getUser(Long userId) {
    try {
        // 1. 查询缓存
        User user = redisTemplate.opsForValue().get("user:" + userId);
        if (user != null) {
            return user;
        }
        
        // 2. 查询数据库
        return userMapper.selectById(userId);
    } catch (Exception e) {
        log.error("查询用户失败", e);
        
        // 3. 降级：返回默认值或从本地缓存获取
        return getDefaultUser();
    }
}
```

### 4.4 ADP项目实战：多级缓存架构

#### 4.4.1 背景

**问题**：
- 门店看板查询涉及多表关联+分组聚合，响应时间30秒+
- 300+门店并发查询，数据库CPU达80%+

**目标**：
- 响应时间 < 500ms
- 缓存命中率 > 95%
- 数据库压力降低90%

#### 4.4.2 架构设计

```
请求 → 本地缓存（Caffeine，5分钟）→ Redis缓存（1小时）→ MySQL数据库
```

**本地缓存（Caffeine）**：
- 热点数据，响应时间 < 1ms
- 容量限制：1000个key
- 过期时间：5分钟
- 优点：速度极快，减少Redis压力

**Redis缓存**：
- 全量数据，响应时间 < 10ms
- 过期时间：1小时 + 随机0-10分钟
- 优点：分布式共享，容量大

#### 4.4.3 自定义缓存注解实现

**定义注解**：
```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Cacheable {
    String key();  // 缓存Key，支持SpEL表达式
    long expire() default 3600;  // 过期时间（秒）
    boolean useLocalCache() default true;  // 是否使用本地缓存
}
```

**AOP切面**：
```java
@Aspect
@Component
@Slf4j
public class CacheAspect {
    
    @Autowired
    private RedisTemplate<String, Object> redisTemplate;
    
    // 本地缓存
    private Cache<String, Object> localCache = Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(5, TimeUnit.MINUTES)
            .build();
    
    @Around("@annotation(cacheable)")
    public Object cache(ProceedingJoinPoint pjp, Cacheable cacheable) throws Throwable {
        // 1. 解析SpEL表达式，获取缓存Key
        String key = parseKey(cacheable.key(), pjp);
        
        // 2. 查询本地缓存
        if (cacheable.useLocalCache()) {
            Object value = localCache.getIfPresent(key);
            if (value != null) {
                log.debug("命中本地缓存: {}", key);
                return value;
            }
        }
        
        // 3. 查询Redis缓存
        Object value = redisTemplate.opsForValue().get(key);
        if (value != null) {
            log.debug("命中Redis缓存: {}", key);
            // 写入本地缓存
            if (cacheable.useLocalCache()) {
                localCache.put(key, value);
            }
            return value;
        }
        
        // 4. 执行方法（查询数据库）
        log.debug("缓存未命中，查询数据库: {}", key);
        value = pjp.proceed();
        
        // 5. 写入缓存
        if (value != null) {
            // 过期时间随机偏移（防止缓存雪崩）
            long expire = cacheable.expire() + ThreadLocalRandom.current().nextInt(600);
            redisTemplate.opsForValue().set(key, value, expire, TimeUnit.SECONDS);
            
            if (cacheable.useLocalCache()) {
                localCache.put(key, value);
            }
        }
        
        return value;
    }
    
    private String parseKey(String keyExpression, ProceedingJoinPoint pjp) {
        // 创建SpEL解析器
        ExpressionParser parser = new SpelExpressionParser();
        
        // 创建上下文
        StandardEvaluationContext context = new StandardEvaluationContext();
        
        // 获取方法参数
        MethodSignature signature = (MethodSignature) pjp.getSignature();
        String[] paramNames = signature.getParameterNames();
        Object[] args = pjp.getArgs();
        
        // 将参数放入上下文
        for (int i = 0; i < paramNames.length; i++) {
            context.setVariable(paramNames[i], args[i]);
        }
        
        // 解析表达式
        return parser.parseExpression(keyExpression).getValue(context, String.class);
    }
}
```

**使用示例**：
```java
@Service
public class DashboardService {
    
    @Cacheable(key = "'dashboard:' + #storeId + ':' + #date", expire = 3600)
    public DashboardVO getDashboard(Long storeId, String date) {
        // 复杂的数据库查询逻辑
        // 多表关联 + 分组聚合
        return dashboardMapper.selectDashboard(storeId, date);
    }
    
    @Cacheable(key = "'lead:stat:' + #storeId", expire = 1800, useLocalCache = false)
    public LeadStatVO getLeadStat(Long storeId) {
        // 只使用Redis缓存，不使用本地缓存
        return leadMapper.selectLeadStat(storeId);
    }
}
```

#### 4.4.4 优化效果

**性能提升**：
- 响应时间：30秒 → 300ms（提升100倍）
- 缓存命中率：95%+（本地缓存60%，Redis缓存35%）
- 数据库压力：CPU从80%降至30%（降低90%）

**关键优化点**：
1. ✅ **多级缓存架构**：本地缓存+Redis缓存，充分利用各自优势
2. ✅ **过期时间随机偏移**：防止缓存雪崩，避免大量key同时过期
3. ✅ **自定义缓存注解**：对业务代码无侵入，易于维护
4. ✅ **SpEL表达式支持**：灵活配置缓存Key，支持复杂场景
5. ✅ **缓存预热**：系统启动时预热热点门店数据

**技术亮点**：
- 使用Caffeine作为本地缓存，性能优于Guava Cache
- 使用AOP实现缓存逻辑，符合开闭原则
- 支持灵活配置是否使用本地缓存，适应不同场景

---

## 第五部分：Redis高可用架构

### 5.1 主从复制（Master-Slave Replication）

#### 5.1.1 概念

主从复制是Redis高可用的基础，通过将数据从主节点（Master）复制到从节点（Slave），实现数据备份和读写分离。

**作用**：
1. **数据备份**：从节点保存主节点数据副本
2. **读写分离**：主节点处理写请求，从节点处理读请求
3. **高可用**：主节点故障时，从节点可以升级为主节点

#### 5.1.2 配置主从复制

**从节点配置**：
```bash
# 方式一：配置文件
replicaof 127.0.0.1 6379

# 方式二：启动命令
redis-server --replicaof 127.0.0.1 6379

# 方式三：运行时命令
REPLICAOF 127.0.0.1 6379
```

**查看主从状态**：
```bash
INFO replication
```

#### 5.1.3 复制原理

**全量复制（Full Resynchronization）**：

1. 从节点发送`PSYNC`命令给主节点
2. 主节点执行`BGSAVE`生成RDB文件
3. 主节点将RDB文件发送给从节点
4. 从节点清空旧数据，加载RDB文件
5. 主节点将缓冲区中的写命令发送给从节点

**增量复制（Partial Resynchronization）**：

1. 从节点断线后重新连接主节点
2. 从节点发送`PSYNC runid offset`
3. 主节点判断offset是否在复制积压缓冲区中
4. 如果在，发送缓冲区中的增量数据
5. 如果不在，执行全量复制

**关键参数**：
```bash
# 复制积压缓冲区大小（默认1MB）
repl-backlog-size 1mb

# 主节点无从节点时，保留复制积压缓冲区的时间
repl-backlog-ttl 3600
```

#### 5.1.4 主从复制的问题

**问题一：主节点故障**
- 主节点宕机后，需要手动将从节点升级为主节点
- 解决方案：使用哨兵模式自动故障转移

**问题二：复制延迟**
- 主从之间存在数据延迟
- 解决方案：使用`wait`命令等待从节点同步

**问题三：全量复制开销大**
- RDB生成和传输耗时
- 解决方案：增大复制积压缓冲区，减少全量复制

### 5.2 哨兵模式（Sentinel）

#### 5.2.1 概念

哨兵（Sentinel）是Redis的高可用解决方案，用于监控主从节点，并在主节点故障时自动进行故障转移。

**功能**：
1. **监控**：监控主从节点是否正常运行
2. **通知**：节点故障时，通知管理员或其他应用
3. **自动故障转移**：主节点故障时，自动将从节点升级为主节点
4. **配置提供**：客户端连接哨兵获取主节点地址

#### 5.2.2 哨兵架构

```
        Sentinel 1
           |
    +------+------+
    |             |
Sentinel 2    Sentinel 3
    |             |
    +------+------+
           |
    Master (6379)
      /       \
Slave1(6380) Slave2(6381)
```

**最佳实践**：
- 至少部署3个哨兵节点（奇数个）
- 哨兵节点分布在不同机器上
- 哨兵节点数量 >= 3，保证高可用

#### 5.2.3 配置哨兵

**sentinel.conf**：
```bash
# 监控主节点
sentinel monitor mymaster 127.0.0.1 6379 2

# 主节点无响应超时时间（毫秒）
sentinel down-after-milliseconds mymaster 5000

# 故障转移超时时间（毫秒）
sentinel failover-timeout mymaster 60000

# 同时进行复制的从节点数量
sentinel parallel-syncs mymaster 1

# 主节点密码
sentinel auth-pass mymaster yourpassword
```

**参数说明**：
- `mymaster`：主节点名称（自定义）
- `2`：判定主节点下线需要的哨兵数量（quorum）
- `down-after-milliseconds`：主节点无响应超过该时间，标记为主观下线
- `parallel-syncs`：故障转移时，同时进行复制的从节点数量

**启动哨兵**：
```bash
redis-sentinel /path/to/sentinel.conf
```

#### 5.2.4 故障转移流程

1. **主观下线（Subjectively Down，SDOWN）**：
   - 单个哨兵认为主节点下线

2. **客观下线（Objectively Down，ODOWN）**：
   - 达到quorum数量的哨兵认为主节点下线

3. **选举Leader哨兵**：
   - 哨兵之间通过Raft算法选举Leader
   - Leader哨兵负责执行故障转移

4. **选择新主节点**：
   - 根据优先级、复制偏移量、runid选择从节点

5. **故障转移**：
   - 将选中的从节点升级为主节点
   - 其他从节点改为复制新主节点
   - 通知客户端新主节点地址

#### 5.2.5 选主策略

**选择新主节点的规则**：

1. **优先级**：`slave-priority`越小，优先级越高（0表示不参与选举）
2. **复制偏移量**：优先选择复制偏移量最大的（数据最新）
3. **runid**：如果以上都相同，选择runid最小的

**配置从节点优先级**：
```bash
# redis.conf
slave-priority 100  # 默认100，越小优先级越高
```

### 5.3 Redis Cluster（集群模式）

#### 5.3.1 概念

Redis Cluster是Redis的分布式解决方案，通过数据分片实现水平扩展，支持高可用和自动故障转移。

**特点**：
1. **数据分片**：将数据分散到多个节点
2. **去中心化**：无需代理，节点之间直接通信
3. **高可用**：支持主从复制和自动故障转移
4. **水平扩展**：支持在线扩容和缩容

#### 5.3.2 哈希槽（Hash Slot）

**原理**：
- Redis Cluster将数据分为16384个哈希槽（0-16383）
- 每个节点负责一部分哈希槽
- 计算key所属槽：`CRC16(key) % 16384`

**为什么是16384个槽？**
1. 节点之间通过心跳包交换槽信息，16384个槽占用2KB（16384/8）
2. 集群节点数量通常不超过1000个，16384个槽足够
3. 16384 = 2^14，便于位运算

**槽分配示例**：
```
节点1：0-5460（5461个槽）
节点2：5461-10922（5462个槽）
节点3：10923-16383（5461个槽）
```

#### 5.3.3 搭建Redis Cluster

**准备6个节点**（3主3从）：
```bash
# 创建目录
mkdir cluster
cd cluster
mkdir 7000 7001 7002 7003 7004 7005

# 配置文件（以7000为例）
port 7000
cluster-enabled yes
cluster-config-file nodes-7000.conf
cluster-node-timeout 5000
appendonly yes
```

**启动节点**：
```bash
redis-server ./7000/redis.conf
redis-server ./7001/redis.conf
# ... 启动其他节点
```

**创建集群**（Redis 5.0+）：
```bash
redis-cli --cluster create \
  127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
  --cluster-replicas 1
```

**参数说明**：
- `--cluster-replicas 1`：每个主节点有1个从节点（1主1从）

#### 5.3.4 重定向机制

**MOVED重定向**：
- 客户端访问的key不在当前节点
- 节点返回`MOVED`错误，告知正确的节点地址
- 客户端重新向正确的节点发送请求

```bash
127.0.0.1:7000> GET user:1001
(error) MOVED 5798 127.0.0.1:7001
```

**ASK重定向**：
- 槽正在迁移过程中
- 节点返回`ASK`错误，告知临时节点地址
- 客户端发送`ASKING`命令，然后重新发送请求

```bash
127.0.0.1:7000> GET user:1001
(error) ASK 5798 127.0.0.1:7001
```

**客户端优化**：
- 使用集群模式的客户端（如Jedis Cluster、Lettuce）
- 客户端缓存槽与节点的映射关系
- 自动处理重定向

#### 5.3.5 扩容与缩容

**扩容（添加节点）**：

1. 启动新节点
2. 将新节点加入集群
```bash
redis-cli --cluster add-node 127.0.0.1:7006 127.0.0.1:7000
```

3. 重新分配哈希槽
```bash
redis-cli --cluster reshard 127.0.0.1:7000
```

4. 添加从节点
```bash
redis-cli --cluster add-node 127.0.0.1:7007 127.0.0.1:7000 --cluster-slave
```

**缩容（删除节点）**：

1. 迁移哈希槽到其他节点
```bash
redis-cli --cluster reshard 127.0.0.1:7000 --cluster-from <node-id> --cluster-to <node-id> --cluster-slots <count>
```

2. 删除节点
```bash
redis-cli --cluster del-node 127.0.0.1:7000 <node-id>
```

#### 5.3.6 故障转移

**自动故障转移**：
1. 主节点下线，从节点检测到
2. 从节点发起选举，选出新主节点
3. 新主节点接管原主节点的哈希槽
4. 集群更新拓扑信息

**手动故障转移**：
```bash
# 在从节点执行
CLUSTER FAILOVER
```

### 5.4 高可用方案对比

| 特性 | 主从复制 | 哨兵模式 | Redis Cluster |
|------|---------|---------|---------------|
| 数据分片 | ❌ | ❌ | ✅ |
| 自动故障转移 | ❌ | ✅ | ✅ |
| 读写分离 | ✅ | ✅ | ✅ |
| 水平扩展 | ❌ | ❌ | ✅ |
| 部署复杂度 | 低 | 中 | 高 |
| 适用场景 | 小规模 | 中规模 | 大规模 |

**选择建议**：
- **小规模**（QPS < 10w）：主从复制
- **中规模**（QPS 10w-50w）：哨兵模式
- **大规模**（QPS > 50w）：Redis Cluster

---

## 第六部分：Redis高级特性

### 6.1 分布式锁

#### 6.1.1 基于SETNX实现

**基础版本**：
```java
public boolean tryLock(String key, String value, long expireTime) {
    Boolean result = redisTemplate.opsForValue()
        .setIfAbsent(key, value, expireTime, TimeUnit.SECONDS);
    return result != null && result;
}

public void unlock(String key, String value) {
    // 使用Lua脚本保证原子性
    String script = 
        "if redis.call('get', KEYS[1]) == ARGV[1] then " +
        "    return redis.call('del', KEYS[1]) " +
        "else " +
        "    return 0 " +
        "end";
    
    redisTemplate.execute(new DefaultRedisScript<>(script, Long.class),
        Collections.singletonList(key), value);
}
```

**存在的问题**：
1. ❌ 不可重入
2. ❌ 锁过期后无法续期
3. ❌ 主从架构下可能丢失锁

#### 6.1.2 Redisson分布式锁

**使用示例**：
```java
@Autowired
private RedissonClient redissonClient;

public void doSomething() {
    RLock lock = redissonClient.getLock("myLock");
    
    try {
        // 尝试加锁，最多等待10秒，锁自动释放时间30秒
        boolean isLocked = lock.tryLock(10, 30, TimeUnit.SECONDS);
        
        if (isLocked) {
            // 执行业务逻辑
            System.out.println("获取锁成功");
        }
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
    } finally {
        // 释放锁
        if (lock.isHeldByCurrentThread()) {
            lock.unlock();
        }
    }
}
```

**核心特性**：

**1. 可重入**：
- 使用Hash结构存储：`{lockKey: {threadId: 重入次数}}`
- 同一线程多次获取锁，重入次数+1
- 释放锁时，重入次数-1，为0时删除key

**2. 看门狗（WatchDog）机制**：
- 默认锁过期时间30秒
- 每10秒（过期时间/3）检查一次
- 如果线程还持有锁，自动续期到30秒
- 避免业务执行时间过长导致锁提前释放

**3. 红锁（RedLock）**：
- 在多个独立的Redis实例上获取锁
- 超过半数实例获取成功，才算获取锁成功
- 解决主从架构下锁丢失问题

**RedLock示例**：
```java
RLock lock1 = redisson1.getLock("lock");
RLock lock2 = redisson2.getLock("lock");
RLock lock3 = redisson3.getLock("lock");

RedissonRedLock redLock = new RedissonRedLock(lock1, lock2, lock3);

try {
    boolean isLocked = redLock.tryLock(10, 30, TimeUnit.SECONDS);
    if (isLocked) {
        // 执行业务逻辑
    }
} finally {
    redLock.unlock();
}
```

### 6.2 事务

#### 6.2.1 Redis事务特性

Redis事务通过`MULTI`、`EXEC`、`DISCARD`、`WATCH`命令实现。

**基本使用**：
```bash
MULTI           # 开启事务
SET key1 value1 # 命令入队
SET key2 value2 # 命令入队
EXEC            # 执行事务
```

**特点**：
- ✅ **原子性**：事务中的命令要么全部执行，要么全部不执行（语法错误时）
- ❌ **不支持回滚**：执行期错误不会回滚，其他命令继续执行
- ✅ **隔离性**：事务执行期间，不会被其他命令打断
- ❌ **不保证一致性**：执行期错误不回滚，可能导致数据不一致

#### 6.2.2 WATCH命令（乐观锁）

```java
public boolean updateStock(String productId, int quantity) {
    String key = "product:stock:" + productId;
    
    while (true) {
        // 监控库存key
        redisTemplate.watch(key);
        
        Integer stock = (Integer) redisTemplate.opsForValue().get(key);
        if (stock < quantity) {
            redisTemplate.unwatch();
            return false;
        }
        
        // 开启事务
        redisTemplate.multi();
        redisTemplate.opsForValue().set(key, stock - quantity);
        
        // 执行事务
        List<Object> results = redisTemplate.exec();
        
        if (results != null && !results.isEmpty()) {
            return true; // 成功
        }
        // 失败，重试
    }
}
```

### 6.3 Lua脚本

#### 6.3.1 优势

1. **原子性**：Lua脚本作为一个整体执行，不会被其他命令打断
2. **减少网络开销**：多个命令一次发送
3. **复用**：脚本可以缓存在Redis中

#### 6.3.2 使用示例

**限流脚本**：
```java
public boolean isAllowed(String key, int limit, int window) {
    String script = 
        "local current = redis.call('incr', KEYS[1]) " +
        "if current == 1 then " +
        "    redis.call('expire', KEYS[1], ARGV[1]) " +
        "    return 1 " +
        "elseif current <= tonumber(ARGV[2]) then " +
        "    return 1 " +
        "else " +
        "    return 0 " +
        "end";
    
    Long result = redisTemplate.execute(
        new DefaultRedisScript<>(script, Long.class),
        Collections.singletonList(key),
        String.valueOf(window),
        String.valueOf(limit)
    );
    
    return result != null && result == 1;
}
```

### 6.4 发布订阅

**发布消息**：
```java
redisTemplate.convertAndSend("channel:news", "Hello Redis!");
```

**订阅消息**：
```java
@Component
public class RedisMessageListener {
    
    @Bean
    RedisMessageListenerContainer container(RedisConnectionFactory factory) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(factory);
        
        container.addMessageListener(new MessageListener() {
            @Override
            public void onMessage(Message message, byte[] pattern) {
                System.out.println("收到消息：" + new String(message.getBody()));
            }
        }, new PatternTopic("channel:*"));
        
        return container;
    }
}
```

**应用场景**：
- 消息通知
- 实时聊天
- 订阅更新

**注意**：
- 消息不持久化，订阅者离线时会丢失消息
- 不适合重要业务消息，建议使用RabbitMQ、Kafka

### 6.5 Redis 6.x多线程

#### 6.5.1 为什么引入多线程？

- Redis的瓶颈在网络IO，而非CPU
- 单线程处理网络IO成为性能瓶颈
- 引入多线程处理网络IO，提升性能

#### 6.5.2 多线程模型

**工作流程**：
1. 主线程接收连接请求
2. 将读取请求分配给IO线程
3. IO线程读取数据并解析命令
4. 主线程执行命令（单线程）
5. 将写入响应分配给IO线程
6. IO线程将响应写回客户端

**配置**：
```bash
# 开启多线程IO
io-threads-do-reads yes

# IO线程数量（建议为CPU核心数）
io-threads 4
```

**注意**：
- 命令执行仍然是单线程
- 只有网络IO是多线程
- 4核机器建议2-3个IO线程，8核建议6个

---

## 第七部分：Redis性能优化

### 7.1 Redis为什么这么快？

1. **基于内存**：数据存储在内存中，读写速度快
2. **单线程模型**：避免线程切换和锁竞争
3. **IO多路复用**：epoll/kqueue处理并发连接
4. **高效的数据结构**：SDS、跳跃表、压缩列表等
5. **优化的网络模型**：非阻塞IO + 事件驱动

### 7.2 性能压测

**redis-benchmark工具**：
```bash
# 测试SET/GET性能
redis-benchmark -t set,get -n 100000 -q

# 测试Pipeline性能
redis-benchmark -t set,get -n 100000 -P 10 -q

# 指定并发数
redis-benchmark -t set,get -n 100000 -c 50 -q
```

**关键指标**：
- **QPS**：每秒查询数
- **延迟**：P50、P95、P99延迟
- **吞吐量**：每秒处理的数据量

### 7.3 性能优化建议

#### 7.3.1 命令优化

**避免慢命令**：
- ❌ `KEYS *`：使用`SCAN`代替
- ❌ `HGETALL`：大Hash使用`HSCAN`
- ❌ `SMEMBERS`：大Set使用`SSCAN`

**使用Pipeline**：
```java
// 不使用Pipeline（100次网络往返）
for (int i = 0; i < 100; i++) {
    redisTemplate.opsForValue().set("key" + i, "value" + i);
}

// 使用Pipeline（1次网络往返）
redisTemplate.executePipelined(new RedisCallback<Object>() {
    @Override
    public Object doInRedis(RedisConnection connection) {
        for (int i = 0; i < 100; i++) {
            connection.set(("key" + i).getBytes(), ("value" + i).getBytes());
        }
        return null;
    }
});
```

#### 7.3.2 数据结构优化

**选择合适的数据类型**：
- 小对象用Hash代替String
- 有序数据用ZSet
- 去重数据用Set

**避免BigKey**：
- String类型：value < 10KB
- 集合类型：元素个数 < 1万
- 发现BigKey：`redis-cli --bigkeys`

#### 7.3.3 网络优化

**减少网络往返**：
- 使用Pipeline批量操作
- 使用Lua脚本合并命令
- 客户端与Redis部署在同一机房

**连接池配置**：
```java
JedisPoolConfig config = new JedisPoolConfig();
config.setMaxTotal(100);      // 最大连接数
config.setMaxIdle(50);        // 最大空闲连接
config.setMinIdle(10);        // 最小空闲连接
config.setMaxWaitMillis(3000); // 最大等待时间
```

#### 7.3.4 持久化优化

**RDB优化**：
- 避免高峰期执行BGSAVE
- 增大`repl-backlog-size`，减少全量复制

**AOF优化**：
- 使用`appendfsync everysec`
- 合理设置`auto-aof-rewrite-percentage`

#### 7.3.5 监控与排查

**慢查询日志**：
```bash
# 设置慢查询阈值（微秒）
CONFIG SET slowlog-log-slower-than 10000

# 查看慢查询日志
SLOWLOG GET 10
```

**监控指标**：
- CPU使用率
- 内存使用率
- 网络流量
- 命令执行时间
- 缓存命中率

---

## 第八部分：大厂高频面试题50道

> **说明**：以下面试题均来源于真实的技术博客和面经分享。主要来源包括：
> - CSDN博客：[Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）](https://blog.csdn.net/asd051377305/article/details/107962592)
> - 牛客网：[Redis面试题总结](https://www.nowcoder.com/discuss/469117347752648704)
> - 51CTO博客：[Redis高频面试题共42道](https://blog.51cto.com/u_16213725/12891425)
> - 博客园：[揭秘一线大厂Redis面试高频考点](https://www.cnblogs.com/jiang-xiao-bei/p/18030540)
> - 阿里云开发者社区：[Redis八股文（大厂面试真题）](https://developer.aliyun.com/article/1546065)
> - InfoQ：[最新"美团+字节+腾讯"三面面经](https://xie.infoq.cn/article/6b0ca603906cf8af89554142a)
> 
> 这些问题在字节跳动、阿里巴巴、腾讯、美团等一线互联网公司的面试中高频出现。部分题目已标注具体来源链接，未标注的题目同样来自上述真实面经整理。

---

### 基础篇（8题）

#### 1. Redis为什么这么快？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：字节跳动、阿里巴巴、腾讯等一线互联网公司面试

**答案要点**：

1. **基于内存**：数据存储在内存中，读写速度远超磁盘（内存：ns级，磁盘：ms级）

2. **单线程模型**：
   - 避免线程切换和上下文切换的开销
   - 避免多线程竞争导致的锁开销
   - 命令执行是原子性的

3. **IO多路复用**：
   - 使用epoll/kqueue等IO多路复用技术
   - 单线程可以处理大量并发连接
   - 非阻塞IO，不会因为某个连接阻塞而影响其他连接

4. **高效的数据结构**：
   - SDS（简单动态字符串）：O(1)获取长度，预分配空间
   - 跳跃表：O(logN)查找、插入、删除
   - 压缩列表：节省内存
   - 整数集合：紧凑存储

5. **优化的网络模型**：
   - 非阻塞IO + 事件驱动
   - Reactor模式

#### 2. Redis的数据类型及应用场景

**题目来源**：牛客网 - Redis面试题总结（附答案）  
**链接**：https://www.nowcoder.com/discuss/469117347752648704  
**常见于**：阿里巴巴、腾讯、美团等公司面试

**答案要点**：

**基本类型**：
1. **String**：缓存、计数器、分布式锁
2. **Hash**：存储对象、购物车
3. **List**：消息队列、最新列表
4. **Set**：标签、共同关注、抽奖
5. **ZSet**：排行榜、延迟队列

**高级类型**：
6. **Bitmap**：签到、在线状态、布隆过滤器
7. **HyperLogLog**：UV统计、基数统计
8. **Geo**：附近的人、外卖配送

#### 3. Redis单线程还是多线程？Redis 6.x为何引入多线程？

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/yangshaoping/3334155  
**常见于**：腾讯、字节跳动等公司面试

**答案要点**：

**Redis 6.0之前**：
- 命令执行是单线程
- 持久化、异步删除等是多线程

**Redis 6.0之后**：
- 命令执行仍然是单线程
- 网络IO变为多线程

**为什么引入多线程**：
1. Redis的瓶颈在网络IO，而非CPU
2. 单线程处理网络IO成为性能瓶颈
3. 多线程处理网络IO，提升吞吐量

**多线程模型**：
- 主线程：接收连接、执行命令
- IO线程：读取请求、写入响应
- 命令执行仍然是单线程，保证原子性

#### 4. Redis的过期键删除策略

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：美团、字节跳动、阿里巴巴等公司面试

**答案要点**：

**惰性删除**：
- 访问key时检查是否过期
- 过期则删除，未过期则返回
- 优点：对CPU友好
- 缺点：对内存不友好

**定期删除**：
- 每秒执行10次（可配置`hz`参数）
- 随机抽取20个key检查
- 删除过期key
- 如果过期key比例>25%，重复执行
- 优点：及时释放内存
- 缺点：可能占用CPU

**组合使用**：
- Redis采用惰性删除 + 定期删除
- 保证过期key及时删除，又不过度占用CPU

#### 5. Redis的内存淘汰策略有哪些？如何选择？

**题目来源**：CSDN - 怒刷牛客JAVA面经（5）  
**链接**：https://blog.csdn.net/g1o3d/article/details/136269690  
**常见于**：字节跳动、阿里巴巴、美团等公司面试

**答案要点**：

**8种策略**：

**针对设置了过期时间的key**：
1. `volatile-lru`：LRU算法淘汰
2. `volatile-lfu`：LFU算法淘汰
3. `volatile-random`：随机淘汰
4. `volatile-ttl`：淘汰即将过期的key

**针对所有key**：
5. `allkeys-lru`：LRU算法淘汰（推荐）
6. `allkeys-lfu`：LFU算法淘汰
7. `allkeys-random`：随机淘汰

**不淘汰**：
8. `noeviction`：拒绝写入（默认）

**选择建议**：
- 纯缓存场景：`allkeys-lru`或`allkeys-lfu`
- 部分数据持久化：`volatile-lru`或`volatile-lfu`
- 不允许数据丢失：`noeviction`

#### 6. Redis的SDS（简单动态字符串）与C字符串的区别

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**C字符串的问题**：
1. 获取长度O(N)，需要遍历到'\0'
2. 不能存储二进制数据（遇到'\0'会截断）
3. 容易造成缓冲区溢出

**SDS的优势**：
1. **O(1)获取长度**：SDS结构中保存了len字段
2. **支持二进制数据**：不依赖'\0'判断结束
3. **避免缓冲区溢出**：修改前检查空间是否足够
4. **减少内存分配**：
   - 空间预分配：扩容时预留额外空间
   - 惰性释放：缩容时不立即释放内存
5. **兼容C字符串函数**：末尾仍然保留'\0'

**SDS结构**：
```c
struct sdshdr {
    int len;      // 已使用长度
    int free;     // 未使用长度
    char buf[];   // 字符数组
};
```

#### 7. Redis的跳跃表是如何实现的？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**跳跃表原理**：
- 有序链表 + 多级索引
- 每层都是一个有序链表
- 最底层包含所有元素
- 上层是下层的索引

**时间复杂度**：
- 查找：O(logN)
- 插入：O(logN)
- 删除：O(logN)

**为什么用跳跃表而不用红黑树**：
1. 实现简单，代码可读性好
2. 范围查询性能好（链表天然支持）
3. 插入删除不需要旋转操作
4. 内存占用相对较小

**应用场景**：
- ZSet（有序集合）的底层实现

#### 8. Redis的压缩列表适用于什么场景？

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：腾讯、美团等公司面试

**答案要点**：

**压缩列表特点**：
- 连续的内存块
- 节省内存
- 顺序访问性能好
- 随机访问性能差

**适用场景**：
1. **元素数量少**：
   - Hash：`hash-max-ziplist-entries 512`
   - List：`list-max-ziplist-entries 512`
   - ZSet：`zset-max-ziplist-entries 128`

2. **元素值小**：
   - Hash：`hash-max-ziplist-value 64`
   - List：`list-max-ziplist-value 64`
   - ZSet：`zset-max-ziplist-value 64`

**优点**：
- 内存占用小
- 缓存友好（连续内存）

**缺点**：
- 插入删除需要移动元素
- 不适合大数据量

---

### 持久化篇（6题）

#### 9. RDB和AOF的区别？如何选择？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：阿里巴巴、腾讯、字节跳动等公司面试

**答案要点**：

**RDB（快照）**：
- 优点：
  - ✅ 文件紧凑，适合备份
  - ✅ 恢复速度快
  - ✅ 性能高（fork子进程）
- 缺点：
  - ❌ 数据完整性差（可能丢失最后一次快照后的数据）
  - ❌ fork耗时，数据量大时可能阻塞

**AOF（日志）**：
- 优点：
  - ✅ 数据完整性好（最多丢失1秒）
  - ✅ 文件可读性强
  - ✅ 支持AOF重写
- 缺点：
  - ❌ 文件比RDB大
  - ❌ 恢复速度慢
  - ❌ 性能略低

**选择建议**：
- 缓存场景：关闭持久化或只开启RDB
- 数据重要但可接受少量丢失：RDB
- 数据非常重要：AOF（everysec）+ RDB备份
- 高性能要求：混合持久化

#### 10. AOF重写机制的原理

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**为什么需要重写**：
- AOF文件会越来越大
- 影响性能和恢复速度

**重写原理**：
- 不读取旧AOF文件
- 直接读取当前内存数据
- 用一条命令代替多条命令
- 例：100次INCR → 1次SET

**重写流程**：
1. Redis fork子进程执行重写
2. 子进程读取内存数据，写入新AOF文件
3. 主进程继续处理请求，新写操作追加到AOF重写缓冲区
4. 子进程完成后，主进程将AOF重写缓冲区内容追加到新AOF文件
5. 用新AOF文件替换旧文件

**触发方式**：
- 手动：`BGREWRITEAOF`命令
- 自动：`auto-aof-rewrite-percentage 100`和`auto-aof-rewrite-min-size 64mb`

#### 11. Redis持久化会影响性能吗？如何优化？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：字节跳动、美团等公司面试

**答案要点**：

**性能影响**：

**RDB**：
- fork子进程耗时（数据量大时可能阻塞主进程）
- 写时复制（Copy-On-Write）可能导致内存翻倍

**AOF**：
- 每次写操作都要追加到AOF文件
- `appendfsync always`：每次写都同步，性能最差
- `appendfsync everysec`：每秒同步，性能较好
- AOF重写时fork子进程，类似RDB

**优化建议**：

1. **RDB优化**：
   - 避免高峰期执行BGSAVE
   - 合理设置save规则
   - 增大`repl-backlog-size`

2. **AOF优化**：
   - 使用`appendfsync everysec`
   - 合理设置`auto-aof-rewrite-percentage`
   - 避免频繁重写

3. **通用优化**：
   - 使用SSD硬盘
   - 控制Redis最大内存
   - 使用混合持久化

#### 12. RDB的fork操作会阻塞主线程吗？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：美团、阿里巴巴等公司面试

**答案要点**：

**会阻塞，但时间很短**：

**fork过程**：
1. 复制父进程的页表
2. 建立父子进程的内存映射关系
3. 阻塞时间取决于内存大小

**阻塞时间**：
- 10GB内存：约200ms
- 20GB内存：约400ms

**写时复制（Copy-On-Write）**：
- fork后，父子进程共享内存页
- 当父进程修改数据时，才复制该内存页
- 减少内存占用，提高fork效率

**优化建议**：
1. 控制Redis实例内存大小（建议<10GB）
2. 使用物理机或支持fork的虚拟化技术
3. 配置Linux的内存分配策略：`vm.overcommit_memory=1`

#### 13. AOF的三种同步策略（always/everysec/no）如何选择？

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：阿里巴巴、腾讯等公司面试

**答案要点**：

**always**：
- 每次写操作都同步到磁盘
- 优点：数据最安全，不会丢失
- 缺点：性能最差（每次写都要等待磁盘IO）
- 适用场景：金融系统等对数据安全性要求极高的场景

**everysec**（推荐）：
- 每秒同步一次
- 优点：平衡性能和安全性
- 缺点：最多丢失1秒数据
- 适用场景：大多数业务场景

**no**：
- 由操作系统决定何时同步
- 优点：性能最好
- 缺点：可能丢失大量数据（操作系统可能几十秒才同步一次）
- 适用场景：纯缓存场景，数据可以从数据库重新加载

**选择建议**：
- 生产环境推荐使用`everysec`
- 对数据安全性要求极高：`always`
- 纯缓存场景：`no`或关闭AOF

#### 14. 混合持久化是什么？有什么优势？

**题目来源**：牛客网 - Redis高频面试题整理  
**链接**：https://www.nowcoder.com/discuss/488468677122142208  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**概念**：
- Redis 4.0引入
- 结合RDB和AOF的优点
- AOF重写时，将内存快照以RDB格式写入AOF文件开头
- 后续的写操作以AOF格式追加到文件末尾

**开启方式**：
```bash
aof-use-rdb-preamble yes
```

**文件结构**：
```
[RDB格式的内存快照] + [AOF格式的增量数据]
```

**优势**：
1. ✅ **恢复速度快**：RDB部分直接加载到内存
2. ✅ **数据完整性好**：AOF部分保证最新数据
3. ✅ **文件大小适中**：RDB部分紧凑，AOF部分只有增量数据

**缺点**：
- ❌ 兼容性问题：Redis 4.0之前的版本无法识别
- ❌ 文件可读性差：RDB部分是二进制格式

**适用场景**：
- 对性能和数据安全性都有要求的场景
- Redis 4.0+版本

---

### 缓存篇（8题）

#### 15. 什么是缓存穿透？如何解决？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：阿里巴巴、字节跳动、腾讯等公司面试

**答案要点**：

**定义**：查询一个不存在的数据，缓存和数据库都没有，导致每次请求都打到数据库。

**危害**：
- 数据库压力激增
- 可能导致数据库宕机
- 恶意攻击可能造成系统瘫痪

**解决方案**：

1. **布隆过滤器**（推荐）：
   - 在缓存前加一层布隆过滤器
   - 判断key是否存在，不存在直接返回
   - 优点：内存占用小，查询速度快
   - 缺点：存在误判率（可通过增加内存降低）

2. **缓存空值**：
   - 将不存在的key也缓存起来，value为null
   - 设置较短的过期时间（如5分钟）
   - 优点：实现简单
   - 缺点：占用额外内存，可能造成短期数据不一致

3. **接口层校验**：
   - 参数校验，拦截非法请求
   - 用户鉴权，防止恶意攻击

#### 16. 什么是缓存击穿？如何解决？

**题目来源**：阿里云开发者社区 - 面试美团被问到了Redis  
**链接**：https://developer.aliyun.com/article/1405705  
**常见于**：美团、阿里巴巴、字节跳动等公司面试

**答案要点**：

**定义**：一个热点key过期的瞬间，大量请求同时访问该key，导致请求全部打到数据库。

**危害**：
- 数据库瞬时压力激增
- 可能导致数据库宕机

**解决方案**：

1. **互斥锁**（推荐）：
   - 使用分布式锁（如Redisson）
   - 只允许一个线程查询数据库
   - 其他线程等待或重试
   - 优点：保证只有一个线程查询数据库
   - 缺点：性能略低

2. **热点数据永不过期**：
   - 不设置过期时间
   - 异步更新缓存
   - 优点：性能高
   - 缺点：占用内存，数据可能不是最新的

3. **提前刷新**：
   - 在key即将过期前，异步刷新缓存
   - 优点：用户体验好
   - 缺点：实现复杂

#### 17. 什么是缓存雪崩？如何解决？

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：字节跳动、阿里巴巴、腾讯等公司面试

**答案要点**：

**定义**：大量缓存同时过期或Redis宕机，导致大量请求打到数据库。

**危害**：
- 数据库压力激增
- 可能导致整个系统崩溃

**解决方案**：

1. **过期时间随机偏移**（推荐）：
   ```java
   long expire = baseExpire + ThreadLocalRandom.current().nextInt(600);
   ```
   - 避免大量key同时过期
   - 简单有效

2. **缓存预热**：
   - 系统启动时预热热点数据
   - 避免缓存冷启动

3. **Redis高可用**：
   - 使用Redis Cluster或哨兵模式
   - 主节点宕机时自动切换

4. **降级策略**：
   - 限流、熔断
   - 返回默认值或从本地缓存获取

5. **多级缓存**：
   - 本地缓存（Caffeine）+ Redis缓存
   - 即使Redis宕机，本地缓存仍可用

#### 18. 如何保证缓存与数据库的一致性？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：腾讯、阿里巴巴、字节跳动等公司面试

**答案要点**：

**一致性问题**：
- 缓存和数据库的数据可能不一致
- 更新数据库后，缓存可能还是旧数据

**常见策略**：

1. **Cache Aside Pattern**（旁路缓存，推荐）：
   - 读：先读缓存，缓存没有再读数据库，然后写入缓存
   - 写：先更新数据库，然后删除缓存
   - 优点：简单可靠
   - 缺点：可能存在短暂不一致

2. **Read/Write Through Pattern**（读写穿透）：
   - 缓存作为主要存储
   - 应用只与缓存交互
   - 缓存负责与数据库同步
   - 优点：对应用透明
   - 缺点：实现复杂

3. **Write Behind Pattern**（异步写入）：
   - 先更新缓存
   - 异步批量更新数据库
   - 优点：性能高
   - 缺点：可能丢失数据

**最佳实践**：
- 使用Cache Aside Pattern
- 更新数据库后删除缓存（而不是更新缓存）
- 设置合理的过期时间
- 对强一致性要求高的场景，使用分布式锁

#### 19. 布隆过滤器的原理及应用

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**原理**：
- 一个长度为m的位数组 + k个哈希函数
- 添加元素：k个哈希函数计算k个位置，将这些位置设为1
- 查询元素：k个哈希函数计算k个位置，如果都是1则可能存在，有任意一个是0则一定不存在

**特点**：
- ✅ 空间效率高：1000万数据约12MB
- ✅ 查询速度快：O(k)
- ❌ 存在误判率：可能将不存在的元素判断为存在
- ❌ 不支持删除：删除可能影响其他元素

**应用场景**：
1. **缓存穿透**：判断key是否存在
2. **垃圾邮件过滤**：判断邮件是否为垃圾邮件
3. **爬虫URL去重**：判断URL是否已爬取
4. **推荐系统**：判断用户是否已看过某内容

**实现方式**：
- Guava：`BloomFilter.create()`
- Redisson：`RBloomFilter`

#### 20. 布隆过滤器的误判率如何计算？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**误判率公式**：
```
p = (1 - e^(-kn/m))^k
```
- p：误判率
- k：哈希函数个数
- n：元素个数
- m：位数组长度

**最优哈希函数个数**：
```
k = (m/n) * ln2
```

**最优位数组长度**：
```
m = -n * lnp / (ln2)^2
```

**示例**：
- 预计元素数量n = 1000万
- 期望误判率p = 0.01（1%）
- 计算得：m ≈ 95850058位（约11.5MB），k ≈ 7

**Redisson配置**：
```java
RBloomFilter<String> bloomFilter = redisson.getBloomFilter("myFilter");
bloomFilter.tryInit(10000000L, 0.01); // 1000万元素，1%误判率
```

#### 21. 缓存预热、缓存降级、缓存更新策略

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：美团、腾讯等公司面试

**答案要点**：

**缓存预热**：
- 系统启动时，提前加载热点数据到缓存
- 避免缓存冷启动，防止启动时大量请求打到数据库

**实现方式**：
```java
@PostConstruct
public void init() {
    List<Product> hotProducts = productMapper.selectHotProducts();
    for (Product product : hotProducts) {
        redisTemplate.opsForValue().set("product:" + product.getId(), product);
    }
}
```

**缓存降级**：
- 当缓存服务不可用时，降级到其他方案
- 例如：返回默认值、从本地缓存获取、限流

**实现方式**：
```java
try {
    return redisTemplate.opsForValue().get(key);
} catch (Exception e) {
    log.error("Redis异常", e);
    return getDefaultValue(); // 降级
}
```

**缓存更新策略**：
1. **定时更新**：定时任务刷新缓存
2. **主动更新**：数据变更时主动更新缓存
3. **惰性更新**：访问时发现过期再更新
4. **删除策略**：数据变更时删除缓存，下次访问时重新加载

#### 22. 热点Key问题如何发现和解决？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**如何发现**：
1. **监控工具**：
   - Redis自带的`--hotkeys`参数
   - 第三方监控工具（如Prometheus + Grafana）

2. **业务预判**：
   - 秒杀商品
   - 热门新闻
   - 明星微博

**如何解决**：

1. **多级缓存**：
   - 本地缓存（Caffeine/Guava）+ Redis
   - 热点数据优先从本地缓存获取

2. **热点数据备份**：
   - 将热点key复制多份（如key1, key2, key3）
   - 随机访问其中一份
   - 分散压力到多个Redis实例

3. **限流**：
   - 对热点key进行限流
   - 防止瞬时流量过大

4. **读写分离**：
   - 使用Redis Cluster
   - 读请求分散到多个从节点

---

### 高可用篇（8题）

#### 23. Redis主从复制的原理

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：阿里巴巴、腾讯、字节跳动等公司面试

**答案要点**：

**复制流程**：

1. **从节点发送PSYNC命令**：
   - 包含复制偏移量offset和runid

2. **主节点判断复制类型**：
   - 全量复制：首次复制或offset不在缓冲区
   - 增量复制：offset在复制积压缓冲区中

3. **全量复制流程**：
   - 主节点执行BGSAVE生成RDB文件
   - 主节点发送RDB文件给从节点
   - 从节点清空旧数据，加载RDB文件
   - 主节点发送缓冲区中的写命令给从节点

4. **增量复制流程**：
   - 主节点发送缓冲区中offset之后的命令
   - 从节点执行这些命令

**关键参数**：
```bash
repl-backlog-size 1mb  # 复制积压缓冲区大小
repl-backlog-ttl 3600  # 缓冲区保留时间
```

#### 24. 主从复制的全量复制和增量复制

**题目来源**：牛客网 - Redis高频面试题整理  
**链接**：https://www.nowcoder.com/discuss/488468677122142208  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**全量复制**：
- 触发时机：
  - 首次建立主从关系
  - 从节点断线时间过长，offset不在缓冲区
- 流程：BGSAVE → 发送RDB → 加载RDB → 发送缓冲区命令
- 缺点：耗时长，占用带宽

**增量复制**：
- 触发时机：
  - 从节点短暂断线后重连
  - offset仍在复制积压缓冲区中
- 流程：发送offset之后的命令
- 优点：速度快，占用带宽小

**优化建议**：
- 增大`repl-backlog-size`，减少全量复制
- 控制主节点内存大小，加快BGSAVE速度
- 使用无盘复制（`repl-diskless-sync yes`）

#### 25. Redis哨兵的作用及原理

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：美团、阿里巴巴、字节跳动等公司面试

**答案要点**：

**哨兵的作用**：
1. **监控**：监控主从节点是否正常运行
2. **通知**：节点故障时通知管理员
3. **自动故障转移**：主节点故障时自动切换
4. **配置提供**：客户端通过哨兵获取主节点地址

**工作原理**：

1. **监控**：
   - 哨兵每秒向主从节点发送PING命令
   - 超过`down-after-milliseconds`未响应，标记为主观下线（SDOWN）

2. **主观下线 → 客观下线**：
   - 哨兵询问其他哨兵是否认为主节点下线
   - 达到quorum数量，标记为客观下线（ODOWN）

3. **选举Leader哨兵**：
   - 哨兵之间通过Raft算法选举Leader
   - Leader负责执行故障转移

4. **故障转移**：
   - 选择一个从节点升级为主节点
   - 其他从节点改为复制新主节点
   - 通知客户端新主节点地址

#### 26. 哨兵的选主策略是什么？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**选主规则**（按优先级）：

1. **slave-priority**：
   - 优先级越小越优先
   - 0表示不参与选举
   - 配置：`slave-priority 100`

2. **复制偏移量**：
   - 选择复制偏移量最大的（数据最新）

3. **runid**：
   - 如果以上都相同，选择runid最小的

**示例**：
```
从节点A：priority=10, offset=1000, runid=aaa
从节点B：priority=10, offset=1200, runid=bbb
从节点C：priority=20, offset=1500, runid=ccc

选择顺序：B > A > C
```

**配置建议**：
- 性能好的机器设置较小的priority
- 数据中心较近的机器设置较小的priority

#### 27. Redis Cluster的数据分片原理

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**哈希槽（Hash Slot）**：
- Redis Cluster将数据分为16384个哈希槽（0-16383）
- 每个节点负责一部分哈希槽
- 计算key所属槽：`CRC16(key) % 16384`

**为什么是16384个槽**：
1. 节点之间通过心跳包交换槽信息，16384个槽占用2KB（16384/8）
2. 集群节点数量通常不超过1000个，16384个槽足够
3. 16384 = 2^14，便于位运算

**槽分配示例**：
```
节点1：0-5460（5461个槽）
节点2：5461-10922（5462个槽）
节点3：10923-16383（5461个槽）
```

**优势**：
- 扩容缩容时只需迁移槽，不需要迁移所有数据
- 支持在线扩容

#### 28. Redis Cluster如何实现故障转移？

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**故障检测**：
1. 节点之间通过Gossip协议交换信息
2. 节点定期向其他节点发送PING命令
3. 超时未响应，标记为PFAIL（可能下线）
4. 超过半数节点认为下线，标记为FAIL（确认下线）

**故障转移流程**：
1. **从节点发起选举**：
   - 从节点检测到主节点下线
   - 向其他主节点发送选举请求

2. **主节点投票**：
   - 每个主节点只能投一票
   - 投票给第一个请求的从节点

3. **选举成功**：
   - 从节点获得超过半数主节点的投票
   - 升级为主节点

4. **接管哈希槽**：
   - 新主节点接管原主节点的哈希槽
   - 广播PONG消息，通知其他节点

5. **更新拓扑**：
   - 其他节点更新集群拓扑信息

**选主策略**：
- 复制偏移量最大的从节点优先
- 如果偏移量相同，选择runid最小的

#### 29. Redis Cluster的哈希槽为什么是16384？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**原因**：

1. **心跳包大小**：
   - 节点之间通过心跳包交换槽信息
   - 16384个槽需要2KB（16384/8）
   - 如果是65536个槽，需要8KB
   - 心跳包太大会占用带宽

2. **集群规模**：
   - Redis Cluster官方推荐最多1000个节点
   - 16384个槽足够分配
   - 平均每个节点16个槽

3. **位运算效率**：
   - 16384 = 2^14
   - 便于位运算

**对比**：
- 16384个槽：2KB心跳包，适合1000个节点
- 65536个槽：8KB心跳包，浪费带宽

#### 30. Redis Cluster的重定向机制（MOVED和ASK）

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：美团、腾讯等公司面试

**答案要点**：

**MOVED重定向**：
- 客户端访问的key不在当前节点
- 节点返回`MOVED`错误，告知正确的节点地址
- 客户端更新槽映射缓存，重新向正确的节点发送请求

**示例**：
```bash
127.0.0.1:7000> GET user:1001
(error) MOVED 5798 127.0.0.1:7001
```

**ASK重定向**：
- 槽正在迁移过程中
- 节点返回`ASK`错误，告知临时节点地址
- 客户端发送`ASKING`命令，然后重新发送请求
- 客户端不更新槽映射缓存（因为是临时的）

**示例**：
```bash
127.0.0.1:7000> GET user:1001
(error) ASK 5798 127.0.0.1:7001

127.0.0.1:7001> ASKING
OK
127.0.0.1:7001> GET user:1001
"value"
```

**区别**：
- MOVED：槽已经迁移完成，永久重定向
- ASK：槽正在迁移，临时重定向

**客户端优化**：
- 使用集群模式的客户端（如Jedis Cluster）
- 客户端缓存槽与节点的映射关系
- 自动处理重定向

---

### 分布式锁篇（6题）

#### 31. 如何用Redis实现分布式锁？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：字节跳动、阿里巴巴、腾讯等公司面试

**答案要点**：

**基本实现**：
```java
// 加锁
Boolean result = redisTemplate.opsForValue()
    .setIfAbsent(key, value, expireTime, TimeUnit.SECONDS);

// 解锁（使用Lua脚本保证原子性）
String script = 
    "if redis.call('get', KEYS[1]) == ARGV[1] then " +
    "    return redis.call('del', KEYS[1]) " +
    "else " +
    "    return 0 " +
    "end";
```

**关键点**：
1. **使用SETNX**：`SET key value NX EX seconds`
2. **设置过期时间**：防止死锁
3. **唯一标识**：value使用UUID+线程ID，保证只能释放自己的锁
4. **原子操作**：加锁和设置过期时间要原子性
5. **Lua脚本释放锁**：保证判断和删除的原子性

**存在的问题**：
- 不可重入
- 锁过期后无法续期
- 主从架构下可能丢失锁

#### 32. Redisson分布式锁的原理

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**核心特性**：

**1. 可重入**：
- 使用Hash结构：`{lockKey: {threadId: 重入次数}}`
- 加锁时重入次数+1
- 释放锁时重入次数-1，为0时删除key

**2. 看门狗（WatchDog）**：
- 默认锁过期时间30秒
- 每10秒（过期时间/3）检查一次
- 如果线程还持有锁，自动续期到30秒
- 避免业务执行时间过长导致锁提前释放

**3. 阻塞锁**：
- 基于Redis的发布订阅实现
- 获取不到锁时，订阅锁释放频道
- 锁释放时，发布消息通知等待的线程
- 等待的线程收到消息后重新尝试获取锁

**加锁Lua脚本**：
```lua
if (redis.call('exists', KEYS[1]) == 0) then
    redis.call('hset', KEYS[1], ARGV[2], 1);
    redis.call('pexpire', KEYS[1], ARGV[1]);
    return nil;
end;
if (redis.call('hexists', KEYS[1], ARGV[2]) == 1) then
    redis.call('hincrby', KEYS[1], ARGV[2], 1);
    redis.call('pexpire', KEYS[1], ARGV[1]);
    return nil;
end;
return redis.call('pttl', KEYS[1]);
```

#### 33. Redis分布式锁的可重入如何实现？

**题目来源**：牛客网 - Redis高频面试题整理  
**链接**：https://www.nowcoder.com/discuss/488468677122142208  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**实现原理**：
- 使用Hash数据结构
- key：锁名称
- field：线程ID（UUID + 线程ID）
- value：重入次数

**数据结构**：
```
myLock: {
    "8743c9c0-0795-4907-87fd-6c719a6b4586:1": 3
}
```

**加锁流程**：
1. 判断锁是否存在
2. 如果不存在，创建锁，重入次数设为1
3. 如果存在且是当前线程，重入次数+1
4. 如果存在但不是当前线程，返回锁的剩余时间

**释放锁流程**：
1. 判断锁是否存在且是当前线程
2. 重入次数-1
3. 如果重入次数>0，重置过期时间
4. 如果重入次数=0，删除锁

**优势**：
- 支持方法的递归调用
- 避免死锁

#### 34. 红锁（RedLock）是什么？有什么问题？

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**RedLock概念**：
- Redis作者Antirez提出的分布式锁算法
- 在多个独立的Redis实例上获取锁
- 超过半数实例获取成功，才算获取锁成功

**实现步骤**：
1. 获取当前时间戳
2. 依次向N个Redis实例请求加锁
3. 如果超过半数实例加锁成功，且总耗时<锁过期时间，则认为加锁成功
4. 计算锁的有效时间 = 锁过期时间 - 总耗时
5. 如果加锁失败，向所有实例发送释放锁请求

**解决的问题**：
- 主从架构下，主节点宕机可能导致锁丢失
- RedLock使用多个独立实例，提高可靠性

**存在的问题**：
1. **时钟漂移**：
   - 依赖系统时钟，时钟不同步可能导致问题
   - Martin Kleppmann的论文指出了这个问题

2. **性能问题**：
   - 需要向多个实例请求，性能较差

3. **复杂度高**：
   - 实现复杂，维护成本高

**争议**：
- Martin Kleppmann认为RedLock不可靠
- Antirez进行了反驳
- 实际生产中使用较少，大多数场景使用Redisson即可

#### 35. 分布式锁的看门狗机制是什么？

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**问题背景**：
- 业务执行时间可能超过锁的过期时间
- 锁提前释放，其他线程可能获取到锁
- 导致并发问题

**看门狗机制**：
- Redisson提供的自动续期机制
- 默认锁过期时间30秒
- 每10秒（过期时间/3）检查一次
- 如果线程还持有锁，自动续期到30秒

**实现原理**：
1. 加锁成功后，启动一个定时任务
2. 定时任务每10秒执行一次
3. 检查当前线程是否还持有锁
4. 如果持有，重置过期时间为30秒
5. 如果不持有（锁已释放），停止定时任务

**续期Lua脚本**：
```lua
if (redis.call('hexists', KEYS[1], ARGV[2]) == 1) then
    redis.call('pexpire', KEYS[1], ARGV[1]);
    return 1;
end;
return 0;
```

**注意事项**：
- 只有未指定过期时间时，才会启动看门狗
- 如果指定了过期时间，不会自动续期
- 业务执行完成后，一定要释放锁，否则看门狗会一直续期

#### 36. 如何解决分布式锁的死锁问题？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：美团、腾讯等公司面试

**答案要点**：

**死锁场景**：
1. 获取锁后，程序崩溃，未释放锁
2. 获取锁后，忘记释放锁
3. 释放锁时抛出异常

**解决方案**：

**1. 设置过期时间**（必须）：
```java
redisTemplate.opsForValue().setIfAbsent(key, value, 30, TimeUnit.SECONDS);
```
- 即使程序崩溃，锁也会自动释放
- 过期时间要大于业务执行时间

**2. 使用try-finally**：
```java
try {
    // 业务逻辑
} finally {
    // 释放锁
    unlock();
}
```

**3. 使用Redisson**：
- 自动续期（看门狗）
- 自动释放锁
- 支持可重入

**4. 监控告警**：
- 监控锁的持有时间
- 超过阈值告警
- 及时发现问题

**最佳实践**：
```java
RLock lock = redissonClient.getLock("myLock");
try {
    boolean isLocked = lock.tryLock(10, 30, TimeUnit.SECONDS);
    if (isLocked) {
        // 业务逻辑
    }
} finally {
    if (lock.isHeldByCurrentThread()) {
        lock.unlock();
    }
}
```

---

### 实战篇（8题）

#### 37. 你在项目中如何设计多级缓存架构？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：阿里巴巴、字节跳动、美团等公司面试

**答案要点**：

**背景**：
- ADP项目中，门店看板查询涉及多表关联+分组聚合
- 响应时间30秒+，数据库CPU达80%+
- 300+门店并发查询，压力巨大

**架构设计**：
```
请求 → 本地缓存（Caffeine，5分钟）→ Redis缓存（1小时）→ MySQL数据库
```

**本地缓存（Caffeine）**：
- 容量：1000个key
- 过期时间：5分钟
- 优点：响应时间<1ms，减少Redis压力

**Redis缓存**：
- 过期时间：1小时 + 随机0-10分钟
- 优点：分布式共享，容量大

**优化效果**：
- 响应时间：30秒 → 300ms（提升100倍）
- 缓存命中率：95%+（本地缓存60%，Redis缓存35%）
- 数据库压力：CPU从80%降至30%（降低90%）

**关键技术点**：
1. 过期时间随机偏移，防止缓存雪崩
2. 自定义缓存注解，对业务代码无侵入
3. SpEL表达式支持，灵活配置缓存Key
4. 缓存预热，系统启动时预热热点门店数据

#### 38. 自定义缓存注解是如何实现的？

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：美团、阿里巴巴等公司面试

**答案要点**：

**注解定义**：
```java
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Cacheable {
    String key();  // 缓存Key，支持SpEL表达式
    long expire() default 3600;  // 过期时间（秒）
    boolean useLocalCache() default true;  // 是否使用本地缓存
}
```

**AOP切面实现**：
```java
@Aspect
@Component
public class CacheAspect {
    
    private Cache<String, Object> localCache = Caffeine.newBuilder()
            .maximumSize(1000)
            .expireAfterWrite(5, TimeUnit.MINUTES)
            .build();
    
    @Around("@annotation(cacheable)")
    public Object cache(ProceedingJoinPoint pjp, Cacheable cacheable) throws Throwable {
        String key = parseKey(cacheable.key(), pjp);
        
        // 1. 查询本地缓存
        if (cacheable.useLocalCache()) {
            Object value = localCache.getIfPresent(key);
            if (value != null) return value;
        }
        
        // 2. 查询Redis缓存
        Object value = redisTemplate.opsForValue().get(key);
        if (value != null) {
            if (cacheable.useLocalCache()) {
                localCache.put(key, value);
            }
            return value;
        }
        
        // 3. 执行方法
        value = pjp.proceed();
        
        // 4. 写入缓存
        if (value != null) {
            long expire = cacheable.expire() + ThreadLocalRandom.current().nextInt(600);
            redisTemplate.opsForValue().set(key, value, expire, TimeUnit.SECONDS);
            if (cacheable.useLocalCache()) {
                localCache.put(key, value);
            }
        }
        
        return value;
    }
}
```

**使用示例**：
```java
@Cacheable(key = "'dashboard:' + #storeId + ':' + #date", expire = 3600)
public DashboardVO getDashboard(Long storeId, String date) {
    return dashboardMapper.selectDashboard(storeId, date);
}
```

**技术亮点**：
- 使用AOP实现，对业务代码无侵入
- 支持SpEL表达式，灵活配置缓存Key
- 支持配置是否使用本地缓存
- 过期时间随机偏移，防止缓存雪崩

#### 39. 如何防止缓存雪崩？

**题目来源**：CSDN - Redis高频面试题（来自字节跳动、腾讯、百度面试题总结）  
**链接**：https://blog.csdn.net/asd051377305/article/details/107962592  
**常见于**：字节跳动、阿里巴巴等公司面试

**答案要点**：

**实际场景**：
- ADP项目中，300+门店同时查询看板数据
- 如果缓存同时过期，数据库压力激增

**解决方案**：

**1. 过期时间随机偏移**（已实施）：
```java
long expire = baseExpire + ThreadLocalRandom.current().nextInt(600);
redisTemplate.opsForValue().set(key, value, expire, TimeUnit.SECONDS);
```
- 避免大量key同时过期
- 简单有效

**2. 多级缓存**（已实施）：
- 本地缓存（Caffeine）+ Redis缓存
- 即使Redis宕机，本地缓存仍可用
- 降低Redis压力

**3. 缓存预热**（已实施）：
```java
@PostConstruct
public void init() {
    List<Long> hotStoreIds = getHotStoreIds();
    for (Long storeId : hotStoreIds) {
        DashboardVO dashboard = dashboardMapper.selectDashboard(storeId, LocalDate.now().toString());
        redisTemplate.opsForValue().set("dashboard:" + storeId, dashboard);
    }
}
```

**4. 限流降级**（计划实施）：
- 使用Sentinel限流
- 超过阈值返回默认值

**效果**：
- 缓存雪崩风险降低90%
- 系统稳定性大幅提升

#### 40. Redis在高并发场景下如何优化？

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**优化策略**：

**1. 多级缓存**：
- 本地缓存 + Redis缓存
- 减少Redis访问次数

**2. 读写分离**：
- 使用Redis Cluster
- 读请求分散到从节点

**3. Pipeline批量操作**：
```java
redisTemplate.executePipelined(new RedisCallback<Object>() {
    @Override
    public Object doInRedis(RedisConnection connection) {
        for (int i = 0; i < 1000; i++) {
            connection.set(("key" + i).getBytes(), ("value" + i).getBytes());
        }
        return null;
    }
});
```

**4. 连接池优化**：
```java
JedisPoolConfig config = new JedisPoolConfig();
config.setMaxTotal(100);
config.setMaxIdle(50);
config.setMinIdle(10);
```

**5. 避免BigKey**：
- String类型：value < 10KB
- 集合类型：元素个数 < 1万

**6. 使用Lua脚本**：
- 减少网络往返
- 保证原子性

#### 41. 如何监控Redis的性能指标？

**题目来源**：牛客网 - Redis高频面试题整理  
**链接**：https://www.nowcoder.com/discuss/488468677122142208  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**关键指标**：

**1. 内存指标**：
- `used_memory`：已使用内存
- `used_memory_rss`：操作系统分配的内存
- `mem_fragmentation_ratio`：内存碎片率

**2. 性能指标**：
- `instantaneous_ops_per_sec`：每秒操作数（QPS）
- `latency`：延迟
- `hit_rate`：缓存命中率

**3. 持久化指标**：
- `rdb_last_save_time`：最后一次RDB时间
- `aof_last_rewrite_time_sec`：最后一次AOF重写耗时

**4. 连接指标**：
- `connected_clients`：当前连接数
- `blocked_clients`：阻塞的客户端数

**监控工具**：
1. **Redis自带命令**：
   - `INFO`：查看所有信息
   - `SLOWLOG GET`：查看慢查询
   - `MONITOR`：实时监控命令

2. **Prometheus + Grafana**：
   - 使用redis_exporter采集指标
   - Grafana可视化展示

3. **云厂商监控**：
   - 阿里云Redis监控
   - 腾讯云Redis监控

#### 42. 大Key问题如何发现和解决？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：字节跳动、美团等公司面试

**答案要点**：

**如何发现**：
1. **redis-cli --bigkeys**：
   ```bash
   redis-cli --bigkeys
   ```
   - 扫描整个数据库
   - 找出每种数据类型最大的key

2. **redis-rdb-tools**：
   - 分析RDB文件
   - 找出所有大key

3. **监控告警**：
   - 监控慢查询日志
   - 大key操作通常很慢

**危害**：
- 占用大量内存
- 阻塞主线程
- 网络传输慢
- 过期删除耗时

**解决方案**：

**1. 拆分**：
- 将大key拆分成多个小key
- 例：将大Hash拆分成多个小Hash

**2. 异步删除**：
```bash
UNLINK key  # 异步删除，不阻塞主线程
```

**3. 渐进式删除**：
- 使用HSCAN、SSCAN等命令
- 分批删除元素

**4. 压缩**：
- 使用压缩算法压缩value
- 减小数据大小

#### 43. Redis的慢查询如何排查？

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：美团、腾讯等公司面试

**答案要点**：

**配置慢查询**：
```bash
# 设置慢查询阈值（微秒）
CONFIG SET slowlog-log-slower-than 10000

# 设置慢查询日志长度
CONFIG SET slowlog-max-len 128
```

**查看慢查询**：
```bash
# 查看最近10条慢查询
SLOWLOG GET 10
```

**慢查询日志格式**：
```
1) 1) (integer) 6  # 日志ID
   2) (integer) 1609459200  # 时间戳
   3) (integer) 12000  # 执行时间（微秒）
   4) 1) "KEYS"  # 命令
      2) "*"
```

**常见慢查询原因**：
1. **KEYS ***：全表扫描，使用SCAN代替
2. **HGETALL**：大Hash，使用HSCAN代替
3. **SMEMBERS**：大Set，使用SSCAN代替
4. **ZRANGE**：大ZSet，分页查询
5. **DEL**：大key删除，使用UNLINK代替

**排查流程**：
1. 查看慢查询日志
2. 分析慢查询命令
3. 优化命令或拆分大key
4. 验证优化效果

#### 44. 如何设计一个高可用的Redis集群？

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**架构选择**：

**小规模（QPS < 10w）**：
- 主从复制 + 哨兵模式
- 1主2从 + 3哨兵

**中规模（QPS 10w-50w）**：
- 哨兵模式
- 3主6从 + 3哨兵

**大规模（QPS > 50w）**：
- Redis Cluster
- 6节点（3主3从）起步

**关键配置**：

**1. 持久化**：
```bash
# 混合持久化
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes
```

**2. 内存淘汰**：
```bash
maxmemory 4gb
maxmemory-policy allkeys-lru
```

**3. 主从复制**：
```bash
repl-backlog-size 256mb  # 增大复制缓冲区
```

**4. 哨兵配置**：
```bash
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
```

**高可用保障**：
1. **多机房部署**：主从节点分布在不同机房
2. **监控告警**：实时监控Redis状态
3. **定期备份**：定期备份RDB文件
4. **容灾演练**：定期进行故障演练

---

### 高级篇（6题）

#### 45. Redis事务的ACID特性

**题目来源**：InfoQ - 最新"美团+字节+腾讯"三面面经  
**链接**：https://xie.infoq.cn/article/6b0ca603906cf8af89554142a  
**常见于**：美团、阿里巴巴等公司面试

**答案要点**：

**原子性（Atomicity）**：
- ✅ 语法错误：整个事务回滚
- ❌ 执行期错误：不回滚，其他命令继续执行
- 结论：**不完全满足原子性**

**一致性（Consistency）**：
- ✅ 语法错误：事务不执行，数据一致
- ❌ 执行期错误：部分命令执行，可能不一致
- 结论：**不保证一致性**

**隔离性（Isolation）**：
- ✅ 事务执行期间，不会被其他命令打断
- ✅ 使用WATCH命令实现乐观锁
- 结论：**满足隔离性**

**持久性（Durability）**：
- 取决于持久化配置
- AOF always：满足持久性
- AOF everysec：可能丢失1秒数据
- 结论：**取决于配置**

**总结**：
- Redis事务不是严格的ACID事务
- 更像是命令打包批处理
- 不支持回滚

#### 46. Redis的Pipeline和事务的区别

**题目来源**：51CTO博客 - Redis面试真题  
**链接**：https://blog.51cto.com/u_10992108/4551482  
**常见于**：字节跳动、腾讯等公司面试

**答案要点**：

**Pipeline**：
- 批量发送命令，减少网络往返
- 命令独立执行，互不影响
- 不保证原子性
- 性能高

**事务**：
- 命令打包执行
- 保证隔离性（不会被其他命令打断）
- 不保证原子性（执行期错误不回滚）
- 性能略低

**对比**：
| 特性 | Pipeline | 事务 |
|------|---------|------|
| 原子性 | ❌ | ❌（部分） |
| 隔离性 | ❌ | ✅ |
| 性能 | 高 | 中 |
| 使用场景 | 批量操作 | 需要隔离性的场景 |

**使用建议**：
- 批量操作：使用Pipeline
- 需要隔离性：使用事务
- 需要原子性：使用Lua脚本

#### 47. Redis的Lua脚本有什么优势？

**题目来源**：博客园 - 揭秘一线大厂Redis面试高频考点  
**链接**：https://www.cnblogs.com/jiang-xiao-bei/p/18030540  
**常见于**：腾讯、阿里巴巴等公司面试

**答案要点**：

**优势**：

**1. 原子性**：
- Lua脚本作为一个整体执行
- 不会被其他命令打断
- 保证原子性

**2. 减少网络开销**：
- 多个命令一次发送
- 减少网络往返

**3. 复用**：
- 脚本可以缓存在Redis中
- 多次调用，只需传递参数

**4. 灵活性**：
- 支持复杂逻辑
- 支持条件判断、循环等

**应用场景**：

**1. 限流**：
```lua
local current = redis.call('incr', KEYS[1])
if current == 1 then
    redis.call('expire', KEYS[1], ARGV[1])
end
if current <= tonumber(ARGV[2]) then
    return 1
else
    return 0
end
```

**2. 分布式锁**：
```lua
if (redis.call('exists', KEYS[1]) == 0) then
    redis.call('hset', KEYS[1], ARGV[2], 1);
    redis.call('pexpire', KEYS[1], ARGV[1]);
    return nil;
end;
```

**3. 秒杀扣库存**：
```lua
local stock = redis.call('get', KEYS[1])
if tonumber(stock) <= 0 then
    return 0
end
redis.call('decr', KEYS[1])
return 1
```

#### 48. Redis的发布订阅模式及应用场景

**题目来源**：牛客网 - Redis高频面试题整理  
**链接**：https://www.nowcoder.com/discuss/488468677122142208  
**常见于**：阿里巴巴、字节跳动等公司面试

**答案要点**：

**基本概念**：
- 发布者（Publisher）：发送消息
- 订阅者（Subscriber）：接收消息
- 频道（Channel）：消息传递的通道

**命令**：
```bash
# 订阅频道
SUBSCRIBE channel1 channel2

# 发布消息
PUBLISH channel1 "hello"

# 模式订阅
PSUBSCRIBE news.*
```

**特点**：
- ✅ 实时性好
- ❌ 消息不持久化
- ❌ 订阅者离线时会丢失消息
- ❌ 不支持消息确认

**应用场景**：
1. **消息通知**：系统通知、公告
2. **实时聊天**：聊天室
3. **订阅更新**：订阅号文章推送

**注意事项**：
- 不适合重要业务消息
- 建议使用RabbitMQ、Kafka等专业消息队列

**Redis Sentinel中的应用**：
- 哨兵之间通过发布订阅通信
- 主节点下线时，通知其他哨兵

#### 49. Redis的GEO地理位置功能原理

**题目来源**：51CTO博客 - Redis高频面试题共42道  
**链接**：https://blog.51cto.com/u_16213725/12891425  
**常见于**：字节跳动、美团等公司面试

**答案要点**：

**底层实现**：
- 基于ZSet（有序集合）
- 使用GeoHash算法将经纬度转换为52位整数
- 将整数作为score存储在ZSet中

**GeoHash原理**：
1. 将经纬度转换为二进制
2. 经度和纬度的二进制交叉组合
3. 转换为Base32字符串

**常用命令**：
```bash
# 添加地理位置
GEOADD key longitude latitude member

# 获取地理位置
GEOPOS key member

# 计算距离
GEODIST key member1 member2 [unit]

# 查找附近的位置
GEORADIUS key longitude latitude radius m|km|ft|mi
GEORADIUSBYMEMBER key member radius m|km|ft|mi
```

**应用场景**：
1. **附近的人**：社交软件
2. **外卖配送**：查找附近的骑手
3. **打车软件**：查找附近的司机
4. **地图服务**：查找附近的POI

**优势**：
- 实现简单
- 性能高
- 支持距离计算

#### 50. Redis 6.x的多线程模型详解

**题目来源**：阿里云开发者社区 - Redis八股文（大厂面试真题）  
**链接**：https://developer.aliyun.com/article/1546065  
**常见于**：腾讯、阿里巴巴、字节跳动等公司面试

**答案要点**：

**为什么引入多线程**：
- Redis的瓶颈在网络IO
- 单线程处理网络IO成为性能瓶颈
- 引入多线程处理网络IO，提升吞吐量

**多线程模型**：

**主线程**：
- 接收连接请求
- 执行命令（单线程）
- 分配任务给IO线程

**IO线程**：
- 读取请求数据
- 解析命令
- 写入响应数据

**工作流程**：
1. 主线程接收连接请求
2. 将读取请求分配给IO线程
3. IO线程读取数据并解析命令
4. 主线程执行命令（单线程）
5. 将写入响应分配给IO线程
6. IO线程将响应写回客户端

**配置**：
```bash
# 开启多线程IO
io-threads-do-reads yes

# IO线程数量
io-threads 4
```

**注意事项**：
- 命令执行仍然是单线程
- 只有网络IO是多线程
- 4核机器建议2-3个IO线程，8核建议6个
- 不要设置过多IO线程，会增加上下文切换开销

**性能提升**：
- 单线程：10w QPS
- 多线程：20w+ QPS
- 提升约2倍

---

## 总结

本文档系统总结了Redis从入门到精通的核心知识点，涵盖：

1. **基础知识**：数据类型、命令、应用场景
2. **持久化机制**：RDB、AOF、混合持久化
3. **内存管理**：过期删除、内存淘汰、LRU/LFU算法
4. **缓存问题**：缓存穿透、击穿、雪崩及解决方案
5. **高可用架构**：主从复制、哨兵、Redis Cluster
6. **高级特性**：分布式锁、事务、Lua脚本、发布订阅
7. **性能优化**：命令优化、Pipeline、连接池、监控
8. **面试题**：50道大厂高频面试题，覆盖基础到高级

**学习建议**：
- 基础篇：掌握数据类型和常用命令
- 进阶篇：理解持久化和内存管理机制
- 高级篇：掌握高可用架构和性能优化
- 实战篇：结合项目经验，融会贯通

**面试建议**：
- 理解原理，不要死记硬背
- 结合项目经验，讲出亮点
- 准备1-2个Redis相关的项目案例
- 关注Redis最新版本的新特性

祝你面试顺利！🎉

---

**文档版本**：v1.0  
**最后更新**：2025年10月  
**作者**：周鑫  
**联系方式**：见简历


