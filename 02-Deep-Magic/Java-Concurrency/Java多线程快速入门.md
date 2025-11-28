# Java 多线程快速入门

> 配套文档：《多线程能力实战知识汇总.md》
> 
> 目标：用最少的时间，让已经会 Java 的人，把多线程的 **70% 核心** 搞明白，然后再去看实战文档做深入。

---

## 0. 谁适合看？看完能干啥？

**适用人群：**
- 会写 Java Web（Spring / Spring Boot），但并发没系统学过；
- 用过一点 `@Async`、`new Thread`、`Executors`，但心里没谱。

**看完这篇，你至少要能做到：**
1. 用一两句话说清楚：为什么要多线程，多线程常见问题是什么；
2. 知道线上代码应该**统一用线程池**，而不是到处 `new Thread`；
3. 会写一个简单的 `CompletableFuture` 并行查询，把 3～5 个接口从串行改成并行；
4. 知道 ThreadLocal 会泄漏、`Executors.newFixedThreadPool()` 会出事、`CompletableFuture` 默认会吞异常；
5. 知道下一步去《多线程能力实战知识汇总》里看哪几个章节做深入。

---

## 1. 为什么要多线程？（先把问题说清楚）

**业务里常见的三类问题：**
- **CPU 太闲**：机器 8 核，只用了一核在跑单线程计算；
- **IO 太慢**：线程在等数据库 / HTTP / MQ，CPU 闲着；
- **数据太多**：一次要处理几十万条记录，单线程要跑半天。

**一句话：**
> 多线程的目的，就是把「等待时间」和「多核 CPU」吃满，
> 让 CPU 干活，不是让它发呆。

不用一上来背 JMM，只要记住：
- 提高吞吐量；
- 降低单次请求的响应时间。

---

## 2. Java 里怎么用线程？（先知道什么是“错的”）

### 2.1 `new Thread`：只适合 Demo，不适合线上

```java
Thread t = new Thread(() -> {
    // 业务逻辑
});

t.start();
```

问题：
- 线程数量失控（谁管？）；
- 异常没人收（跑挂就没了）；
- 不能统一配置名称、监控、拒绝策略。

> 线上代码里，`new Thread` 大量出现，就是设计失败。

### 2.2 正确方向：只关心「任务」，线程交给线程池

```java
ExecutorService pool = Executors.newFixedThreadPool(4);

pool.submit(() -> doSomething());   // 提交任务

// 程序结束时
pool.shutdown();                     // 优雅关闭
```

**入门阶段先理解这个模型：**
- 你只关心「要跑哪些任务」；
- 线程的创建 / 复用 / 回收，交给线程池。

> 生产环境请不要直接用 `Executors` 这一套创建线程池，
> 详细原因和替代方案见《多线程能力实战知识汇总》中的「1.5 线程池的 3 个致命坑」。

---

## 3. 线程池：先会用，再慢慢学细节

### 3.1 执行流程，一句话版

> 提交任务 → 尽量用「核心线程」处理 → 核心都忙就进队列 → 队列也满了再开「非核心线程」 → 实在扛不住就走「拒绝策略」。

你能把这句话顺畅地说出来，就算通过「线程池流程」入门关。

完整流程图和参数细节，见实战文档：
- 《多线程能力实战知识汇总》 → **1.1 线程池执行流程**

### 3.2 一个「像样一点」的配置长什么样？

```java
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    8,              // 核心线程数
    16,             // 最大线程数
    60L, TimeUnit.SECONDS,
    new LinkedBlockingQueue<>(1000)  // 有界队列
);
```

你现在只需要能看懂：
- 有「核心线程数」和「最大线程数」；
- 有「队列容量」，不是无限大；
- 后面可以配置「拒绝策略」。

怎么根据 CPU/IO 负载选这些数字，见实战文档：
- **1.2 线程池参数配置决策表**

---

## 4. CompletableFuture：把串行改成并行

这是你在业务里**最容易立刻用起来**的东西。

### 4.1 两个核心 API

- `runAsync(Runnable, executor)`：异步执行「无返回值」的任务；
- `supplyAsync(Supplier<T>, executor)`：异步执行「有返回值」的任务；
- `allOf(f1, f2, ...)`：等待多个任务全部完成。

### 4.2 简单并行查询示例

```java
CompletableFuture<User> userFuture =
    CompletableFuture.supplyAsync(() -> loadUser(), executor);

CompletableFuture<Order> orderFuture =
    CompletableFuture.supplyAsync(() -> loadOrder(), executor);

// 等两者都完成
CompletableFuture.allOf(userFuture, orderFuture).join();

User user = userFuture.join();
Order order = orderFuture.join();
```

效果：
- 以前是：查用户 1s + 查订单 1s ≈ 2s；
- 现在是：两者一起查，总耗时 ≈ max(1s, 1s) ≈ 1s。

### 4.3 异常必须处理

```java
CompletableFuture.supplyAsync(() -> load(), executor)
    .exceptionally(ex -> {
        log.error("load failed", ex);
        return defaultValue();
    });
```

记住一句话：
> CompletableFuture 默认会「吞异常」，不自己处理就等于没打日志、没报警。

更复杂的并行查询、编排案例，见实战文档：
- **2.1 CompletableFuture 并行查询优化**
- **2.2 实战案例：线索详情并行查询**

---

## 5. ThreadLocal / TTL：上下文与内存泄漏

### 5.1 ThreadLocal 的基本用法

```java
try {
    UserContext.set(user);
    // 业务逻辑
} finally {
    UserContext.remove();  // 必须 remove
}
```

你只需要先记住两点：
1. ThreadLocal 用来给「当前线程」存放一些上下文（比如当前登录用户）；
2. **用完一定要 `remove()`，否则会内存泄漏。**

内存泄漏的原理图和血泪教训，见实战文档：
- **4.1 ThreadLocal 内存泄漏问题**
- **六、血泪教训汇总 → 坑2：ThreadLocal 内存泄漏**

### 5.2 在线程池下，需要用 TTL 传递上下文

普通 ThreadLocal 在「线程池」里会有上下文丢失问题，这时需要：
- `TransmittableThreadLocal`（TTL）
- `TtlExecutors.getTtlExecutor(executor)` 包装线程池

完整实战配置和示例，见实战文档：
- **4.2 TransmittableThreadLocal 上下文传递**

---

## 6. 入门阶段一定要知道的三大坑

1. **不要直接用 `Executors.newFixedThreadPool()` 在线上创建线程池**
   - 问题：内部默认是「无界队列」，容易撑爆内存；
   - 详细分析见实战文档：
     - **1.5 血泪教训：线程池的 3 个致命坑 → 坑1**。

2. **ThreadLocal 用完不 `remove()` 会内存泄漏**
   - 模板：`try { set } finally { remove }`；
   - 详细说明见：
     - **4.1 ThreadLocal 内存泄漏问题**。

3. **CompletableFuture 不处理异常，就是「偷偷失败」**
   - 至少要加 `.exceptionally(...)` 打日志；
   - 总结见：
     - **六、血泪教训汇总 → 坑3：CompletableFuture 异常被吞**。

---

## 7. 下一步：如何配合《多线程能力实战精华》学习？

如果你把这篇快速入门看完了，建议按下面路线继续：

1. **线程池搞清楚（必读）**
   - 《多线程能力实战知识汇总》：
     - 1.1 线程池执行流程（流程图）
     - 1.2 线程池参数配置决策表
     - 1.3 项目中的 3 个线程池
     - 1.5 线程池的 3 个致命坑

2. **CompletableFuture 深入用法（强烈推荐）**
   - 2.1 CompletableFuture 并行查询优化
   - 2.2 实战案例：线索详情并行查询
   - 3.2 CompletableFuture 多阶段编排

3. **线程安全与上下文传递（按需）**
   - 零章：并发编程核心原理（JMM / synchronized / AQS / CAS）
   - 4.1、4.2：ThreadLocal / TransmittableThreadLocal

4. **准备面试 / 系统复盘**
   - 7. 面试高频速记
   - 8. 总结与最佳实践

> 入门时，不要被所有名词吓到。先把「线程池 + CompletableFuture + ThreadLocal」这三件事用顺手，再回头看底层原理和高级玩法。
