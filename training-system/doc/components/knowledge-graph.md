# Component: Knowledge Graph (知识图谱)

> 定义知识的结构、依赖关系、以及如何组织成可学习的路径。

---

## 职责

1. 存储所有知识节点及其属性
2. 维护节点之间的依赖关系（DAG）
3. 提供拓扑排序和学习路径推荐
4. 支持知识节点的版本化管理

---

## 数据模型

### KnowledgeNode

```yaml
KnowledgeNode:
  id: string                    # 唯一标识，如 "K_data_structures"
  name: string                  # 显示名称
  category: string              # 分类：tools | cs_fundamentals | engineering | domain | soft_skills
  description: string           # 一句话描述
  
  # 层次化深度
  depth_target: 1 | 2 | 3      # 推荐掌握层次
  
  # 权重体系
  weight: float                 # 对目标岗位的重要度 (0-1)
  is_core: boolean              # 是否核心知识（是 → 可触发攻坚模式）
  practical_coverage: float     # 20/80 中覆盖的日常场景比例 (0-1)
  
  # 学习成本
  learning_cost_hours: float    # 预估学习时间
  difficulty_rating: 1..5       # 难度评级
  
  # 拓扑
  prerequisites: [string]       # 前置知识节点 ID 列表
  children: [string]            # 可展开的子节点（用于层次化）
  
  # 材料关联
  content_refs:                 # 指向教学材料的引用
    L1: [string]                # L1 实用层材料
    L2: [string]                # L2 原理层材料
    L3: [string]                # L3 元原理层材料
    
  # 评估关联
  assessment_refs: [string]     # 关联的题目/任务 ID
  q_matrix_row: object          # 该节点在 Q-Matrix 中的行（哪些题目考察它）
  
  # 元数据
  version: string
  updated_at: datetime
```

### KnowledgeEdge

```yaml
KnowledgeEdge:
  from: string                  # 源节点 ID
  to: string                    # 目标节点 ID
  type: prerequisite | related | analogous | contradicts
  strength: float               # 关联强度 (0-1)
  description: string           # 关系的自然语言描述
  evidence: string              # 为什么这个关系存在（数据驱动 or 专家定义）
```

---

## 核心算法

### 1. 拓扑排序（学习路径生成）

```
输入：目标知识节点集合 {K_target}, 知识图谱 G
输出：线性学习序列

算法：
  1. 从目标节点出发，DFS 收集所有前置依赖
  2. 构建子图 G' = 所有目标节点 ∪ 所有依赖节点
  3. 对 G' 做 Kahn's topological sort
  4. 同一层级的节点按 weight × practical_coverage 降序排列
  5. 返回有序序列
```

### 2. 缺口追溯

```
输入：学员在节点 K 卡住
输出：最可能的前置知识缺口

算法：
  1. 检查 K 的直接前置节点 {P1, P2, ...}
  2. 对每个 Pi，查询 LearnerModel.p_mastery
  3. 找到 p_mastery 最低且 < mastery_threshold 的 Pi
  4. 递归向上，直到找到真正的根因缺口
  5. 返回缺口路径 [P_root → ... → P_near → K]
```

### 3. 最优路径推荐（基于数据飞轮）

```
输入：学员背景向量 B, 目标节点集合 T
输出：推荐学习路径（有序节点列表）

算法：
  1. 在历史路径库中搜索与 B 相似的学员
  2. 筛选以 T 为目标路径
  3. 按 success_rate 排序
  4. 提取共识子路径（被多个成功学员走过的共同部分）
  5. 对分歧部分用 PageRank 式加权（走过的人越多权重越高）
  6. 返回最优路径
```

---

## 层次化知识（L1/L2/L3 的内容组织）

每个知识节点在不同层次有不同内容：

```yaml
# 以 "K_break_even" 为例
K_break_even:
  depth_target: 2
  
  content_refs:
    L1:
      - "公式卡片: BEP = FC / (P - VC)"
      - "计算器工具: 输入参数 → 输出结果"
      - "例题: 单一产品盈亏平衡计算"
    L2:
      - "原理解析: 成本性态分类 (固定 vs 可变)"
      - "边际贡献概念: 每多卖一单位，多少用于覆盖固定成本"
      - "变式: 多产品组合、阶梯定价下的盈亏平衡"
      - "常见误区: 沉没成本不是固定成本"
    L3:
      - "跨域连接: 盈亏平衡 ↔ 热力学相变 ↔ 网络效应临界质量"
      - "系统思维: 任何系统的阈值/临界点行为"
      - "哲学: 非线性变化——量变累积到某一点后行为质变"
```

当学员在 L1 遇到边界情况 → 系统推送 L2 内容
当学员追问「为什么」超过 2 次 → 系统展示 L3 连接

---

## 20/80 知识识别算法

```
输入：KnowledgeGraph + 历史学员数据
输出：每个节点的 practical_coverage 评分

数据源：
  1. 场景出现频率: 在所有训练场景决策点中，该知识被使用的频率
  2. 面试出现频率: 在目标岗位面经中，该知识被问到的频率
  3. 阻塞度: 有多少其他知识依赖此节点（入度）
  4. 区分度: 成功学员与失败学员在该节点的掌握度差异
  5. 时间成本: 掌握该节点所需时间 vs 其覆盖面

综合评分：
  coverage_score = w1*freq + w2*interview_freq + w3*blocking 
                   + w4*discrimination - w5*time_cost
  
  排序后取前 20% → 标记为高覆盖节点
```

---

## 学习路径复用

系统记录所有学员的实际学习路径：

```
PathRecord {
  learner_id: string
  learner_background: object    # 背景向量（学历、经验、目标等）
  path: [node_id, ...]          # 实际学习顺序
  outcome: "success" | "failed" | "in_progress"
  total_time_hours: float
  satisfaction_score: float
}
```

**路径推荐 API**：

```
GET /api/paths/recommend
  ?goal=junior_software_engineer
  &background={"cs_degree": false, "years_exp": 0, "known_languages": ["python"]}
  
Response:
  paths: [
    {
      name: "实践优先路径",
      sequence: [...],
      success_rate: 0.78,
      estimated_hours: 120,
      match_score: 0.92,        // 与学员背景的匹配度
    },
    ...
  ]
```
