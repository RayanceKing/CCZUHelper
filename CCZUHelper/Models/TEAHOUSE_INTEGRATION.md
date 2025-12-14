# 茶楼模块 Supabase 集成文档

## 📋 概述

本文档描述了茶楼模块与 Supabase 数据库的完整集成方案，包括数据模型、服务层和使用示例。

## 🗂️ 文件结构

```
CCZUHelper/Models/
├── TeahouseModels.swift          # 核心数据模型（对齐 Supabase 数据库）
├── TeahouseService.swift         # 数据服务层（API 调用和实时订阅)
├── TeahouseServiceExamples.swift # 使用示例和 SwiftUI 视图
├── SupabaseClient.swift          # Supabase 客户端配置
├── CommentDTO.swift              # (已弃用，保留向后兼容)
├── LikeDTO.swift                 # (已弃用，保留向后兼容)
└── Banner.swift                  # (已弃用，保留向后兼容)
```

## 📊 数据模型映射

### 数据库表 → Swift 结构体

| 数据库表 | Swift 结构体 | 说明 |
|---------|-------------|------|
| `profiles` | `Profile` | 用户资料 |
| `posts` | `TeahousePostDTO` | 帖子（基础表） |
| `comments` | `Comment` | 评论 |
| `likes` | `Like` | 点赞（无 created_at） |
| `categories` | `Category` | 分类 |
| `banners` | `BannerDTO` | 横幅 |
| `posts_with_metadata` (视图) | `PostWithMetadata` | 带统计数据的帖子 |
| `active_banners` (视图) | `ActiveBanner` | 活跃横幅 |

### 枚举类型

```swift
enum PostStatus: String, Codable {
    case available  // 可用
    case sold       // 已售
    case pending    // 待定
    case archived   // 已归档
}
```

## 🔑 关键设计决策

### 1. UUID vs String

数据库中所有 `uuid` 类型在 Swift 中映射为 `String`，而非 `UUID`。

**原因**：
- Supabase 返回的 JSON 中 UUID 是字符串格式
- 避免解码时的类型转换问题
- 保持与 TypeScript 定义一致

### 2. image_urls 字段处理

数据库中 `posts.image_urls` 是 `text` 类型（非数组）。

**解决方案**：
```swift
struct TeahousePostDTO {
    let imageUrls: String?  // 数据库字段
    
    var imageUrlsArray: [String] {  // 计算属性
        // 尝试解析为 JSON 数组
        // 或返回单个 URL 的数组
    }
}
```

### 3. 日期处理

所有 `timestamptz` 字段映射为 `Date`，使用 ISO 8601 解码。

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
```

### 4. 可选性规则

- 数据库中 `NOT NULL` → Swift 中非可选
- 数据库中可为空 → Swift 中可选 (`Type?`)

## 🚀 使用指南

### 1. 基础配置

Supabase 客户端已在 `SupabaseClient.swift` 中配置，无需额外设置。

```swift
import Supabase

// 客户端已初始化，直接使用
let client = supabase
```

### 2. 获取瀑布流数据

```swift
@StateObject private var service = TeahouseService()

// 在视图中
.task {
    try? await service.fetchWaterfallPosts(status: [.available, .sold])
}

// 访问数据
ForEach(service.posts) { waterfallPost in
    PostCard(post: waterfallPost)
}
```

### 3. 创建新帖子

```swift
let post = try await service.createPost(
    title: "二手自行车出售",
    content: "9成新，价格可议",
    categoryId: 1,
    imageUrls: ["https://example.com/bike.jpg"],
    price: 200.0,
    isAnonymous: false
)
```

### 4. 更新帖子状态

```swift
try await service.updatePostStatus(
    id: "post-uuid",
    status: .sold
)
```

### 5. 点赞/取消点赞

```swift
try await service.toggleLike(
    postId: "post-uuid",
    userId: "user-uuid"
)
```

### 6. 添加评论

```swift
let comment = try await service.addComment(
    postId: "post-uuid",
    content: "这个价格很合理！",
    parentCommentId: nil,  // 顶级评论
    isAnonymous: false
)
```

### 7. 实时订阅

```swift
// 开启实时订阅（监听帖子状态变化）
service.startRealtimeSubscription()

// 停止订阅
service.stopRealtimeSubscription()
```

**实时更新流程**：
1. 用户 A 将帖子状态改为 "sold"
2. Supabase 触发 realtime 事件
3. 所有订阅的客户端接收更新
4. UI 自动刷新显示新状态

## 📝 API 参考

### TeahouseService 主要方法

| 方法 | 参数 | 返回值 | 说明 |
|-----|------|--------|------|
| `fetchWaterfallPosts(status:)` | `[PostStatus]` | `[WaterfallPost]` | 获取瀑布流帖子 |
| `fetchPost(id:)` | `String` | `WaterfallPost?` | 获取单个帖子详情 |
| `fetchComments(postId:)` | `String` | `[CommentWithProfile]` | 获取帖子评论 |
| `createPost(...)` | 多个参数 | `TeahousePostDTO` | 创建新帖子 |
| `updatePostStatus(id:status:)` | `String, PostStatus` | `Void` | 更新帖子状态 |
| `toggleLike(postId:userId:)` | `String, String` | `Void` | 切换点赞状态 |
| `addComment(...)` | 多个参数 | `Comment` | 添加评论 |
| `startRealtimeSubscription()` | - | `Void` | 开启实时订阅 |
| `stopRealtimeSubscription()` | - | `Void` | 停止实时订阅 |

## ⚠️ 注意事项

### 1. 向后兼容性

旧的 DTO 文件 (`CommentDTO`, `LikeDTO`, `Banner`) 已标记为 `@available(*, deprecated)`，建议迁移到新模型：

- `CommentDTO` → `Comment`
- `LikeDTO` → `Like`
- `Banner` → `BannerDTO` 或 `ActiveBanner`

### 2. 错误处理

所有异步方法都可能抛出错误，建议使用 `do-catch` 或显示错误提示：

```swift
do {
    try await service.fetchWaterfallPosts()
} catch {
    print("加载失败: \(error.localizedDescription)")
    // 显示错误提示
}
```

### 3. 内存管理

`TeahouseService` 使用 `@MainActor`，确保所有 UI 更新在主线程：

```swift
@StateObject private var service = TeahouseService()
```

### 4. Realtime 订阅生命周期

记得在视图消失时停止订阅：

```swift
.onDisappear {
    service.stopRealtimeSubscription()
}
```

## 🔍 数据库查询示例

### 查询带关联的帖子

```swift
// 查询 posts_with_metadata 并关联 profiles
let response = try await supabase
    .from("posts_with_metadata")
    .select("""
        *,
        profile:profiles!user_id (
            username,
            avatar_url
        )
    """)
    .in("status", values: ["available", "sold"])
    .order("created_at", ascending: false)
    .execute()
```

### 过滤和排序

```swift
// 按分类过滤
.eq("category_id", value: 1)

// 价格范围
.gte("price", value: 100)
.lte("price", value: 500)

// 分页
.range(from: 0, to: 19)  // 前 20 条
```

## 📚 参考资源

- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
- [Supabase Realtime 文档](https://supabase.com/docs/guides/realtime)
- [PostgreSQL 数据类型](https://www.postgresql.org/docs/current/datatype.html)

## 🎯 下一步

1. **完善图片上传**：集成 Supabase Storage 用于图片上传
2. **缓存策略**：添加本地缓存减少网络请求
3. **分页加载**：实现无限滚动加载更多帖子
4. **搜索功能**：添加全文搜索支持
5. **推送通知**：集成推送通知提醒新评论/点赞

## 📄 许可证

遵循项目主许可证
