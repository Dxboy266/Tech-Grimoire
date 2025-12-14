# Java面试八股文精华总结（3年经验·大厂突击版·深度加强版）

> **文档说明**：
> *   **适用对象**：3-5年经验Java开发，目标阿里、字节、美团等一线大厂。
> *   **阅读时长**：约 4-6 小时（深度复习）。
> *   **内容策略**：遵循二八原则，覆盖80%的高频核心考点。拒绝无效堆砌，强调**原理深度**、**源码细节**、**生产场景**和**高分回答话术**。
> *   **排版**：核心点加粗，追问环节（🔥）模拟真实面试压力。

---

## 目录
1.  **Java基础与集合 (HashMap源码, 集合体系)**
2.  **Java并发编程 (JUC, 锁, 线程池, JMM)**
3.  **JVM虚拟机 (内存模型, GC, 调优)**
4.  **MySQL数据库 (索引, 事务, 锁, 调优)**
5.  **Redis缓存 (底层结构, 持久化, 集群, 场景)**
6.  **Spring全家桶 (IOC, AOP, Boot原理, 事务)**
7.  **分布式与微服务 (MQ, 分布式锁/事务, CAP)**
8.  **计算机网络 (TCP, HTTP/HTTPS)**
9.  **系统设计与场景题 (秒杀, 短链, 各种排查)**

---

## 一、 Java基础与集合

### 1. HashMap 源码级剖析 (必问)
*   **底层结构**：
    *   **JDK 1.7**：数组 + 链表（头插法，多线程扩容易死循环）。
    *   **JDK 1.8**：数组 + 链表 + 红黑树（尾插法，解决死循环）。
*   **核心参数**：
    *   `DEFAULT_INITIAL_CAPACITY = 16` (默认容量)
    *   `DEFAULT_LOAD_FACTOR = 0.75` (负载因子，空间与时间的折中)
    *   `TREEIFY_THRESHOLD = 8` (链表转红黑树阈值)
    *   `UNTREEIFY_THRESHOLD = 6` (红黑树退化链表阈值)
    *   `MIN_TREEIFY_CAPACITY = 64` (转红黑树的最小数组容量，防止刚初始化就转树)
*   **Put 方法流程 (1.8)**：
    1.  判断数组是否为空，空则 `resize()` 初始化。
    2.  计算 hash：`(h = key.hashCode()) ^ (h >>> 16)` (高低位异或，扰动函数，减少碰撞)。
    3.  计算下标：`(n - 1) & hash`。
    4.  如果下标位置为空，直接插入。
    5.  如果不为空（碰撞）：
        *   如果是红黑树节点，调用 `putTreeVal`。
        *   如果是链表，遍历链表（尾插法）。插入后判断链表长度是否 `>= 8`，是则尝试转红黑树（先判断数组长度是否 `>= 64`，否则只扩容）。
        *   如果 Key 已存在，覆盖 Value。
    6.  `++modCount`，判断 `++size > threshold`，是则 `resize()`。
*   **Resize 扩容机制**：
    *   容量翻倍（x2）。
    *   **1.7**：所有元素重新计算 Hash，重新分布（Rehash）。
    *   **1.8 优化**：不需要重新计算 Hash。利用高位（oldCap）是 0 还是 1 判断。
        *   **0**：原位置。
        *   **1**：原位置 + oldCap。
        *   **优势**：省去了 Hash 计算，且扩容后链表顺序保持一致，避免死循环。

> **🔥 追问：为什么负载因子是 0.75？**
> *   **A**：这是空间成本和时间成本的权衡（Trade-off）。
> *   如果是 1.0：空间利用率高，但哈希碰撞概率大，链表/树变长，查询慢。
> *   如果是 0.5：碰撞少，查询快，但空间浪费一半，扩容频率高。
> *   0.75 是根据泊松分布（Poisson Distribution）统计出来的经验值，在此值下，链表长度达到 8 的概率极低（千万分之一）。

> **🔥 追问：ConcurrentHashMap 1.7 和 1.8 的区别？**
> *   **1.7**：Segment 分段锁（继承 ReentrantLock）+ HashEntry 数组。锁粒度是 Segment（默认 16）。
> *   **1.8**：Node 数组 + CAS + Synchronized。锁粒度是 Node（数组槽位），并发度更高。
> *   **为什么 1.8 用 Synchronized 而不用 ReentrantLock？**
>     *   JVM 团队对 Synchronized 做了大量优化（偏向锁、轻量级锁、锁消除/粗化），性能已经不输 ReentrantLock。
>     *   Synchronized 节省内存（不用继承 AQS 的各种属性）。

### 2. ArrayList vs LinkedList
*   **ArrayList**：动态数组。查询 O(1)，增删 O(n)（需要 System.arraycopy 移动元素）。扩容 1.5 倍。
*   **LinkedList**：双向链表。查询 O(n)，增删 O(1)（前提是已知节点位置，否则查找也要 O(n)）。
*   **大厂偏好**：99% 场景用 ArrayList。因为 ArrayList 内存连续，对 CPU Cache 友好（空间局部性原理）；LinkedList 节点分散，且每个节点多存 prev/next 指针，内存开销大。

---

## 二、 Java并发编程 (JUC)

### 1. JMM (Java Memory Model) & volatile
*   **JMM 三大特性**：原子性、可见性、有序性。
*   **volatile**：
    *   **保证可见性**：通过 MESI 缓存一致性协议（或总线锁）+ 内存屏障。写 volatile 变量会强制刷回主存，并立即使其他线程的缓存失效。
    *   **保证有序性**：禁止指令重排序（通过插入 Memory Barrier）。
    *   **不保证原子性**：`i++` 不是原子的。
*   **DCL 单例 (Double Check Lock)**：
    ```java
    private static volatile Singleton instance; // 必须 volatile，防止指令重排
    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton(); 
                    // 1.分配内存 2.初始化 3.指向内存
                    // 若无 volatile，可能重排为 1->3->2，导致其他线程拿到未初始化的对象
                }
            }
        }
        return instance;
    }
    ```

### 2. Synchronized 锁升级过程
*   **对象头 (Mark Word)**：存储 HashCode、分代年龄、锁标记位。
*   **升级流程**：
    1.  **无锁**。
    2.  **偏向锁**：第一个线程访问，记录 ThreadID。后续该线程再来，无需同步。
    3.  **轻量级锁 (自旋锁)**：有其他线程竞争（交替执行）。通过 CAS 尝试修改 Mark Word 指向线程栈中的 Lock Record。如果失败，自旋（循环等待）。
    4.  **重量级锁 (OS Mutex)**：自旋超过阈值（或竞争激烈），膨胀为重量级锁。线程挂起，进入内核态，性能损耗大。
*   **注意**：JDK 15 默认废弃了偏向锁（因为维护成本高，且现代应用并发度高，偏向锁命中率低）。

### 3. AQS (AbstractQueuedSynchronizer) 深度
*   **核心**：State (资源) + CLH 队列 (双向链表) + CAS。
*   **ReentrantLock**：
    *   **可重入**：state++。
    *   **公平/非公平**：
        *   FairSync: tryAcquire 时先判断 `hasQueuedPredecessors()`（队列里有没有人排队）。
        *   NonfairSync: 直接 CAS 抢，抢不到再排队。
*   **CountDownLatch**：`state = N`，`countDown()` -> `state--`，`await()` 阻塞直到 `state == 0`。不可重用。
*   **CyclicBarrier**：可重用，基于 ReentrantLock + Condition 实现。
*   **Semaphore**：信号量，控制并发数量（限流）。

### 4. ThreadLocal 内存泄漏
*   **原理**：每个 Thread 内部维护一个 `ThreadLocalMap`。Key 是 `ThreadLocal` 实例（**弱引用**），Value 是具体对象（**强引用**）。
*   **泄漏原因**：
    *   GC 时，Key（弱引用）被回收，Key 变为 null。
    *   但 Value（强引用）依然存在，且 ThreadLocalMap 生命周期跟 Thread 一样长（线程池中线程复用，生命周期很长）。
    *   导致 `null -> Value` 的 Entry 无法被访问也无法被回收。
*   **解决**：使用完必须调用 `remove()` 方法。

### 5. 线程池 (ThreadPoolExecutor) 实战
*   **7大参数**：`corePoolSize`, `maxPoolSize`, `keepAliveTime`, `unit`, `workQueue`, `threadFactory`, `handler`。
*   **工作队列**：
    *   `ArrayBlockingQueue`：有界，适合防内存溢出。
    *   `LinkedBlockingQueue`：默认无界（Integer.MAX_VALUE），易 OOM。建议手动指定容量。
    *   `SynchronousQueue`：不存元素，直接移交（CachedThreadPool 用这个）。
*   **拒绝策略**：
    *   `AbortPolicy` (默认，抛异常)。
    *   `CallerRunsPolicy` (调用者运行，**生产常用**，起到削峰反压作用)。
    *   `DiscardPolicy` (丢弃不抛异常)。
    *   `DiscardOldestPolicy` (丢弃队列最老任务)。
*   **线程数配置公式**：
    *   CPU 密集型：`CPU核数 + 1` (防止页缺失/上下文切换)。
    *   IO 密集型：`CPU核数 * 2` 或 `CPU / (1 - 阻塞系数)` (阻塞系数通常 0.8~0.9)。

---

## 三、 JVM 虚拟机

### 1. 内存区域 (Runtime Data Area)
*   **线程私有**：
    *   **程序计数器**：记录当前执行字节码行号（唯一无 OOM 区域）。
    *   **虚拟机栈**：Java 方法栈帧（局部变量表、操作数栈、动态链接、返回地址）。`StackOverflowError`。
    *   **本地方法栈**：Native 方法。
*   **线程共享**：
    *   **堆 (Heap)**：对象实例。分新生代 (Eden, S0, S1) 和老年代。
    *   **方法区 (Method Area)**：类信息、常量、静态变量。
        *   JDK 1.7：永久代 (PermGen)，在堆中。
        *   JDK 1.8：元空间 (Metaspace)，在**本地内存**（Native Memory），不再受堆大小限制，只受物理内存限制。

### 2. GC 垃圾回收
*   **判断对象存活**：
    *   引用计数法（循环引用问题）。
    *   **可达性分析法**（GC Roots：栈变量、静态变量、常量、JNI 指针）。
*   **垃圾回收算法**：
    *   **标记-清除**：碎片多。
    *   **标记-复制**：浪费内存，适合新生代（存活少）。
    *   **标记-整理**：无碎片，移动对象成本高，适合老年代。
*   **垃圾收集器**：
    *   **Serial / Serial Old**：单线程，STW (Stop The World) 长。
    *   **Parallel Scavenge / Old**：多线程吞吐量优先（JDK 8 默认）。
    *   **CMS (Concurrent Mark Sweep)**：低延迟，标记-清除。
        *   流程：初始标记(STW) -> 并发标记 -> 重新标记(STW) -> 并发清除。
        *   缺点：CPU 敏感、浮动垃圾、内存碎片（导致 Full GC）。
    *   **G1 (Garbage First)**：JDK 9 默认。
        *   逻辑分代，物理分区 (Region)。
        *   维护优先列表，优先回收价值大（垃圾多）的 Region。
        *   **核心优势**：可预测停顿时间 (`-XX:MaxGCPauseMillis`)。

### 3. 类加载机制
*   **过程**：加载 -> 验证 -> 准备 (静态变量赋零值) -> 解析 -> 初始化 (执行 clinit)。
*   **双亲委派模型**：
    *   Bootstrap ClassLoader (C++实现, 加载 rt.jar) -> Extension ClassLoader -> App ClassLoader -> Custom ClassLoader。
    *   **原理**：先找父加载器加载，父加载不了再自己加载。
    *   **意义**：沙箱安全机制（防止核心库被篡改，如自定义 java.lang.String）。
*   **打破双亲委派**：
    *   **Tomcat**：为了 WebApp 隔离，优先加载 WebApp 下的类。
    *   **JDBC (SPI)**：DriverManager 加载驱动，父加载器需要调用子加载器的代码。

### 4. JVM 调优实战
*   **常见命令**：
    *   `jps`：查看进程。
    *   `jstat -gcutil PID 1000`：每秒监控 GC 情况（E, O, M, YGC, FGC）。
    *   `jmap -dump:format=b,file=heap.hprof PID`：导出堆快照。
    *   `jstack PID`：查看线程栈（找死锁、死循环）。
*   **OOM 排查思路**：
    1.  导出 Dump 文件。
    2.  使用 MAT / VisualVM 分析。
    3.  查看 Dominator Tree，找到占用内存最大的对象。
    4.  分析 GC Roots 引用链，定位是哪段代码持有了对象不释放。
*   **CPU 100% 排查思路**：
    1.  `top` 查 PID。
    2.  `top -H -p PID` 查耗时线程 TID。
    3.  `printf "%x" TID` 转 16 进制。
    4.  `jstack PID | grep 16进制TID -A 20` 找代码。

---

## 四、 MySQL 数据库

### 1. 索引底层与优化
*   **B+ 树 vs B 树**：
    *   B+ 树数据全在叶子，非叶子只存索引 -> 树更矮（一般 3 层存 2000w 数据），IO 少。
    *   B+ 树叶子有双向链表 -> 范围查询快。
*   **聚簇索引 vs 非聚簇索引**：
    *   聚簇：主键索引，叶子存整行数据。
    *   非聚簇（二级索引）：叶子存主键值。需要**回表**查询。
*   **覆盖索引**：查询列全在索引中，无需回表。`select id, name from table where name = 'abc'` (name有索引)。
*   **最左前缀原则**：联合索引 `(a, b, c)`。
    *   `a=1 and b=2` (走索引)
    *   `a=1 and c=3` (a 走，c 不走)
    *   `b=2 and c=3` (不走索引)
    *   `like 'abc%'` (走)，`like '%abc'` (不走)。
*   **索引失效**：
    *   对索引列运算 `id + 1 = 10`。
    *   类型转换 `str_col = 123`。
    *   `or` 连接的条件如果不全是索引。
    *   `!=`, `<>`。

### 2. 事务与隔离级别
*   **ACID**：
    *   **A (原子性)**：Undo Log (回滚日志)。
    *   **C (一致性)**：最终目标。
    *   **I (隔离性)**：MVCC + 锁。
    *   **D (持久性)**：Redo Log (重做日志，WAL 机制，先写日志再写磁盘)。
*   **隔离级别**：
    *   **Read Uncommitted**：脏读。
    *   **Read Committed (RC)**：不可重复读。每次 Select 生成新 ReadView。
    *   **Repeatable Read (RR)**：MySQL 默认。可重复读。第一次 Select 生成 ReadView，后续复用。解决部分幻读。
    *   **Serializable**：串行化。
*   **MVCC (多版本并发控制)**：
    *   每行记录有隐藏列：`trx_id` (最近修改事务ID), `roll_pointer` (回滚指针)。
    *   Undo Log 形成版本链。
    *   ReadView：`m_ids` (活跃事务列表), `min_trx_id`, `max_trx_id`。
    *   **可见性规则**：
        *   trx_id < min_trx_id：已提交，可见。
        *   trx_id > max_trx_id：未开始，不可见。
        *   trx_id 在 m_ids 中：未提交，不可见（除非是自己）。

### 3. 锁机制
*   **全局锁**：全库只读（做全库备份用）。
*   **表锁**：`lock tables`。
*   **行锁 (InnoDB)**：
    *   **Record Lock**：锁单行。
    *   **Gap Lock**：间隙锁，锁范围 `(5, 10)`，防止插入，解决幻读。
    *   **Next-Key Lock**：Record + Gap，锁 `(5, 10]`。
*   **死锁**：
    *   场景：事务 A 锁 id=1 欲锁 id=2；事务 B 锁 id=2 欲锁 id=1。
    *   解决：开启死锁检测（默认开启），回滚代价小的事务。

### 4. 日志系统 (Log)
*   **Binlog (归档日志)**：Server 层，逻辑日志（SQL 语句/Row 数据），主从复制、数据恢复。
*   **Redo Log (重做日志)**：InnoDB 层，物理日志（页修改），Crash-safe 能力。循环写。
*   **Undo Log (回滚日志)**：逻辑日志（反向操作），事务回滚、MVCC。
*   **两阶段提交 (2PC)**：
    *   保证 Redo Log 和 Binlog 一致性。
    *   Prepare Redo -> Write Binlog -> Commit Redo。

---

## 五、 Redis 缓存

### 1. 核心数据结构与底层
*   **String**: SDS (Simple Dynamic String)。O(1) 获取长度，防缓冲区溢出，空间预分配。
*   **List**: QuickList (ZipList + 双向链表)。
*   **Hash**: ZipList (压缩列表, 元素少时) -> HashTable (扩容时渐进式 Rehash)。
*   **Set**: IntSet (整数数组) -> HashTable。
*   **ZSet**: ZipList -> SkipList (跳表)。
    *   **为什么用跳表不用红黑树？**
        *   范围查找（Range）性能更好（直接遍历链表）。
        *   实现简单，并发调整粒度小。
        *   内存占用略少。

### 2. 持久化 (RDB vs AOF)
*   **RDB (快照)**：
    *   `bgsave`：Fork 子进程（利用 OS 的 Copy-On-Write 机制），不阻塞主线程。
    *   优点：文件小，恢复快。缺点：丢数据多。
*   **AOF (追加日志)**：
    *   记录写命令。
    *   策略：`always` (慢, 安全), `everysec` (默认, 丢1秒), `no`。
    *   **AOF 重写 (Rewrite)**：压缩日志，合并命令。Fork 子进程重写。
*   **混合持久化 (4.0+)**：RDB 镜像 + AOF 增量。

### 3. 过期删除与内存淘汰
*   **删除策略**：
    *   **惰性删除**：查的时候判断过期则删。
    *   **定期删除**：每隔 100ms 随机抽查删除。
*   **内存淘汰策略 (maxmemory-policy)**：
    *   `noeviction`：报错。
    *   `allkeys-lru`：所有 Key 中 LRU（最常用）。
    *   `volatile-lru`：设置了过期的 Key 中 LRU。
    *   `allkeys-random` / `volatile-random`。
    *   `volatile-ttl`：快过期的先删。
    *   **LRU 实现**：Redis 近似 LRU（随机采样），省内存。

### 4. 缓存一致性 (Cache Aside Pattern)
*   **读**：Hit 读缓存 -> Miss 读 DB -> Set 缓存。
*   **写**：先更新 DB -> 后删除缓存。
*   **为什么删而不更？** 懒加载，防止多次更新 DB 期间缓存频繁更新但没人读。
*   **延时双删**：删 -> 写 DB -> sleep(N) -> 删。解决主从同步延迟导致的脏数据。
*   **Canal 方案**：监听 Binlog -> MQ -> 消费者删缓存（解耦，可靠性高）。

### 5. 缓存穿透/击穿/雪崩
*   **穿透**（查不存在）：布隆过滤器 (Bloom Filter) - 有误判（说有不一定有，说无一定无），不支持删除。
*   **击穿**（热点失效）：互斥锁 (SetNX) 或 逻辑过期 (Value 里存过期时间，异步重建)。
*   **雪崩**（集体失效）：随机 TTL，集群高可用，降级限流。

---

## 六、 Spring 全家桶

### 1. Spring IOC & AOP
*   **IOC (控制反转)**：DI (依赖注入)。容器管理 Bean 生命周期。
*   **Bean 生命周期**：
    1.  Instantiation (实例化, new)。
    2.  Populate (属性赋值)。
    3.  Initialization (初始化):
        *   `Aware` 接口回调 (BeanNameAware, BeanFactoryAware)。
        *   `BeanPostProcessor.before` (AOP 在这里可能生成代理)。
        *   `@PostConstruct` / `init-method`。
        *   `BeanPostProcessor.after` (AOP 动态代理主要时机)。
    4.  Destruction (销毁)。
*   **循环依赖**：
    *   **三级缓存**：
        1.  `singletonObjects` (成品池)。
        2.  `earlySingletonObjects` (半成品池，已代理)。
        3.  `singletonFactories` (工厂池，生成代理 lambda)。
    *   **流程**：A 实例化 -> 放入三级缓存 -> 注入 B -> B 实例化 -> 注入 A -> 从三级缓存拿 A (如果是代理则提前创建) -> 移入二级 -> B 初始化完成 -> A 注入 B 完成 -> A 初始化完成 -> 移入一级。
    *   **构造器循环依赖**无法解决（因为无法实例化）。

*   **AOP (面向切面)**：
    *   **JDK 动态代理**：基于接口，反射 (`Proxy.newProxyInstance`)。
    *   **CGLIB**：基于继承 (ASM 修改字节码)，final 类不可代理。
    *   Spring Boot 2.0 后默认 CGLIB (proxy-target-class=true)。

### 2. Spring 事务
*   **传播行为 (Propagation)**：
    *   `REQUIRED` (默认)：有事务就加入，没有就新建。
    *   `REQUIRES_NEW`：挂起当前，新建事务（独立提交回滚）。
    *   `NESTED`：嵌套事务（Savepoint），父回滚子回滚，子回滚父不一定。
*   **失效场景**：
    *   方法非 public。
    *   同类自调用 (this.method() 不走代理)。
    *   异常被 try-catch 吞掉。
    *   数据库引擎不支持 (MyISAM)。

### 3. Spring Boot
*   **自动装配原理**：
    *   `@SpringBootApplication` -> `@EnableAutoConfiguration` -> `@Import(AutoConfigurationImportSelector.class)`。
    *   加载 `META-INF/spring.factories` (2.7前) 或 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`。
    *   根据 `@ConditionalOnClass` 等条件按需加载 Bean。
*   **Starter**：依赖聚合 + 自动配置。

---

## 七、 分布式与微服务

### 1. CAP & BASE
*   **CAP**：Consistency (一致性), Availability (可用性), Partition Tolerance (分区容错性)。P 必须保证，只能在 C 和 A 选。
    *   **CP**: Zookeeper, Consul (强一致，节点挂了可能不可用)。
    *   **AP**: Eureka, Nacos (默认 AP，高可用，最终一致)。
*   **BASE**：Basically Available (基本可用), Soft state (软状态), Eventually consistent (最终一致性)。

### 2. 分布式锁
*   **Redis (Redisson)**：
    *   `setnx` 抢锁。
    *   `lua` 脚本保证原子性 (判断+删除)。
    *   **WatchDog**：后台线程每 10s 续期，防止业务没跑完锁过期。
    *   **RedLock**：多节点（N/2+1）加锁，解决主从切换锁丢失问题（争议大，一般不用）。
*   **Zookeeper**：
    *   临时顺序节点。
    *   最小节点获锁，其他监听前一个节点（公平锁）。
    *   可靠性高（CP），性能不如 Redis。

### 3. 分布式事务
*   **Seata AT**：2PC 改进。
    *   一阶段：执行 SQL，保存 Undo Log (Before/After Image)，提交本地事务。
    *   二阶段 Commit：异步删除 Undo Log。
    *   二阶段 Rollback：根据 Undo Log 反向补偿。
    *   **脏写问题**：引入全局锁。
*   **TCC**：Try (预留), Confirm (确认), Cancel (撤销)。性能好，业务侵入大。
*   **MQ 事务消息 (RocketMQ)**：
    *   半消息 (Half Message) -> 执行本地事务 -> Commit/Rollback。
    *   保证**生产者 -> MQ -> 消费者**的最终一致性。

### 4. 消息队列 (Kafka/RocketMQ)
*   **高吞吐原理 (Kafka)**：
    *   **顺序写**磁盘 (Sequential Write)。
    *   **零拷贝 (Zero Copy)**：`sendfile` (DMA)，减少用户态/内核态切换和数据拷贝。
    *   **批量发送**。
*   **消息不丢失**：
    *   Producer: `acks=all` (所有副本收到)。
    *   Broker: 同步刷盘 (SYNC_FLUSH) + 多副本。
    *   Consumer: 手动提交 Offset。
*   **消息积压**：
    *   扩容 Consumer。
    *   如果 Topic 分区不够，新建 Topic 扩分区，临时 Consumer 搬运。

---

## 八、 计算机网络

### 1. TCP 三次握手 & 四次挥手
*   **三次握手**：
    1.  SYN (Seq=x)
    2.  SYN+ACK (Seq=y, Ack=x+1)
    3.  ACK (Ack=y+1)
    *   **为什么三次？** 防止失效的连接请求突然传到服务端。确认双方收发能力。
*   **四次挥手**：
    1.  FIN
    2.  ACK (半关闭状态，还能收数据)
    3.  FIN (服务端发完数据了)
    4.  ACK -> **TIME_WAIT** (2MSL)
    *   **为什么 TIME_WAIT？** 1. 保证最后一个 ACK 到达（如果丢了服务端会重发 FIN）。2. 等待旧报文在网络中消失。

### 2. HTTP vs HTTPS
*   **HTTPS** = HTTP + SSL/TLS。
*   **握手流程**：
    1.  ClientHello (支持的算法, 随机数1)。
    2.  ServerHello (选定算法, 证书, 随机数2)。
    3.  Client 验证证书。生成预主密钥 (Pre-Master Secret)，用公钥加密发给 Server。
    4.  Server 用私钥解密。
    5.  双方根据 随机数1+2+预主密钥 生成 会话密钥 (Symmetric Key)。
    6.  后续用会话密钥对称加密传输。

---

## 九、 系统设计与场景题 (高频)

### 1. 秒杀系统设计
*   **核心挑战**：高并发读、瞬时高并发写、超卖。
*   **架构分层**：
    *   **客户端**：按钮置灰，倒计时，静态资源 CDN。
    *   **网关层**：限流 (RateLimiter, Nginx 漏桶/令牌桶)，黑名单，鉴权。
    *   **应用层**：
        *   **Redis 预减库存**：Lua 脚本原子操作。`decr` 成功则推入 MQ，失败直接返回“抢光了”。
        *   **本地缓存**：Guava Cache 缓存商品状态（是否卖完），减少 Redis 压力。
    *   **异步层**：MQ 削峰填谷。
    *   **数据库层**：
        *   消费 MQ，扣减库存。
        *   **乐观锁**：`update stock set num = num - 1 where id = x and num > 0`。
        *   **防重**：唯一索引（user_id + sku_id）。

### 2. 短链接系统设计 (TinyURL)
*   **原理**：长 URL -> 映射算法 -> 短 Key -> 存 DB/Redis。访问短 Key -> 302 重定向 -> 长 URL。
*   **Hash 算法**：MurmurHash (冲突少, 速度快)。
*   **冲突解决**：
    *   如果 Hash 冲突，在长 URL 后加随机串再 Hash。
    *   或者用**发号器**（Snowflake / Redis Incr / 数据库自增 ID）转 62 进制 (a-z, A-Z, 0-9)。
*   **存储**：Redis 缓存热点映射，MySQL 存储全量。

### 3. 排行榜设计
*   **Redis ZSet**：
    *   `zadd key score member`
    *   `zrevrange key 0 10 withscores` (Top 10)
*   **分数相同怎么排？**
    *   将时间戳作为小数部分加入分数（分数 = 真实分 + (1e13 - timestamp) / 1e13）。

### 4. 接口幂等性设计
*   **场景**：重复提交、网络重试。
*   **方案**：
    *   **Token 机制**：进入页面申请 Token 存 Redis，提交时带 Token，后端删 Token（原子性）。删成功则执行，失败则重复。
    *   **数据库唯一索引**：业务 ID。
    *   **Redis SetNX**：锁业务 ID。
    *   **状态机**：`update order set status = 'paid' where id = x and status = 'unpaid'`。

---

> **结语**：
> 3年经验面试的核心在于**“体系化”**。不要只背散点，要尝试把知识点串联起来。
> 例如问到 HashMap，可以聊到线程不安全 -> ConcurrentHashMap -> 锁机制 -> CAS -> JMM -> Volatile。
> 问到 MySQL 慢查询，可以聊到 索引 -> 磁盘 IO -> B+树 -> 缓存 -> Redis 一致性。
> **祝你 Offer 拿到手软！**
