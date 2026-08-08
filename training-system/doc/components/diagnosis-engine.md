# Component: Diagnosis Engine (诊断引擎)

> 回答「学员现在会什么、不会什么、为什么不会」。是整个系统的感知层。

---

## 职责

1. 接收 PerformanceRecord，更新知识状态
2. 执行知识追踪（BKT/DKT）
3. 错误归因——区分「不会」的不同原因
4. 检测知识缺口并评估严重程度
5. 监控动机指标（dropout risk、hesitation trend）

---

## 核心模型

### 1. Bayesian Knowledge Tracing (BKT)

经典模型，对每个知识点独立维护掌握概率。

```
状态模型（隐变量）:
  P(L_n)  — 学员在时刻 n 已掌握该知识的概率

观测模型:
  P(correct | L) = 1 - P(S)      # 掌握了但做错（slip）
  P(correct | ~L) = P(G)         # 没掌握但猜对（guess）

四个参数:
  P(L₀)   — 初始掌握概率（先验）
  P(T)    — 从不会到会的转移概率（每次实践后的学习概率）
  P(G)    — 猜测概率
  P(S)    — 失误概率

贝叶斯更新:
  如果答对:
    P(L | correct) = P(L) * (1-P(S)) / [P(L)*(1-P(S)) + (1-P(L))*P(G)]
  如果答错:
    P(L | wrong)   = P(L) * P(S) / [P(L)*P(S) + (1-P(L))*(1-P(G))]
  
  然后加上学习转移:
    P(L_{n+1}) = P(L_n | obs) + (1 - P(L_n | obs)) * P(T)
```

**落地实现**：

```python
class BKTModel:
    def __init__(self, params: BKTParams):
        self.p_initial = params.p_initial    # 默认 0.15
        self.p_learn = params.p_learn        # 默认 0.30
        self.p_guess = params.p_guess        # 默认 0.15
        self.p_slip = params.p_slip          # 默认 0.10
    
    def update(self, p_mastery: float, correct: bool) -> float:
        """一次观测后的掌握概率更新"""
        if correct:
            p_correct_given_learned = 1 - self.p_slip
            p_correct_given_unlearned = self.p_guess
        else:
            p_correct_given_learned = self.p_slip
            p_correct_given_unlearned = 1 - self.p_guess
        
        # Bayes update
        likelihood_learned = p_mastery * p_correct_given_learned
        likelihood_unlearned = (1 - p_mastery) * p_correct_given_unlearned
        p_learned_given_obs = likelihood_learned / (likelihood_learned + likelihood_unlearned)
        
        # Learning transition
        p_new = p_learned_given_obs + (1 - p_learned_given_obs) * self.p_learn
        
        return p_new
```

### 2. 知识衰减

未练习的知识会衰减：

```
P(L_{t+week}) = P(L_t) * (1 - decay_rate)   # 每周衰减
decay_rate: 默认 0.05（每周衰减 5%）
```

### 3. 多知识点扩展（Q-Matrix 驱动）

真实题目往往考察多个知识点。使用 Q-Matrix 分配权重：

```python
def update_from_exercise(exercise_id, performance, q_matrix, learner_state):
    """
    一道题做对/错 → 同时更新多个知识点的掌握概率
    """
    for node_id, weight in q_matrix[exercise_id].items():
        # 该题对该知识点的考察权重
        # 权重越高，该题的对错对该知识点的信息量越大
        effective_performance = performance  # correct: 1, wrong: 0
        
        # 如果权重低（该题不太考察这个知识），贝叶斯更新时放缩 evidence
        adjusted_obs = effective_performance * weight + (1 - weight) * 0.5
        
        # 使用 partial-credit BKT 更新
        learner_state[node_id].p_mastery = bkt_update(
            learner_state[node_id].p_mastery, 
            adjusted_obs
        )
```

---

## 错误归因分类器

### 四种错误类型

| 类型 | 含义 | 检测信号 |
|------|------|----------|
| **concept** | 概念不清，根本不知道这个知识 | 连续错同类题、非计算错误、题干理解正确但答案离谱 |
| **calculation** | 知道概念但计算/操作出错 | 公式对但数字错、中间步骤对最终结果错 |
| **comprehension** | 没理解题目/场景在问什么 | 犹豫时间长、答非所问、正确率随题目表述变化大 |
| **prerequisite** | 前置知识缺失导致当前卡住 | 前置节点 p_mastery 低 + 当前节点概念题对但应用题错 |

### 分类逻辑

```python
def classify_error(exercise_result, learner_state, q_matrix):
    """
    输入：一道题的作答记录
    输出：错误类型 + 置信度
    """
    
    # Rule 1: 如果前置知识 p < 0.5 → prerequisite
    prereqs = get_prerequisites(exercise_result.knowledge_tested)
    weakest_prereq = min(prereqs, key=lambda k: learner_state[k].p_mastery)
    if learner_state[weakest_prereq].p_mastery < 0.5:
        return ErrorType.PREREQUISITE, weakest_prereq, confidence=0.80
    
    # Rule 2: 如果犹豫时间长 (>avg) 且答非所问 → comprehension
    if (exercise_result.hesitation_sec > learner_state.avg_hesitation * 1.5 
        and exercise_result.answer_relevance < 0.3):
        return ErrorType.COMPREHENSION, confidence=0.70
    
    # Rule 3: 如果中间步骤对但最终结果错 → calculation
    if (exercise_result.intermediate_steps_correct > 0.7 
        and exercise_result.final_correct == False):
        return ErrorType.CALCULATION, confidence=0.85
    
    # Rule 4: 默认 → concept
    return ErrorType.CONCEPT, confidence=0.60
```

---

## 缺口检测与严重度评估

```python
class GapDetector:
    def detect(self, decision_point_result, learner_state, knowledge_graph):
        gaps = []
        
        for node_id in decision_point_result.knowledge_tested:
            p = learner_state[node_id].p_mastery
            node = knowledge_graph.get_node(node_id)
            
            severity = self._assess_severity(p, node)
            
            if severity != "none":
                gaps.append(GapReport(
                    node_id=node_id,
                    p_mastery=p,
                    severity=severity,
                    attribution=classify_error(...),
                    evidence=collect_evidence(node_id, learner_state),
                    recommended_action=self._action_for_severity(severity, node)
                ))
        
        return gaps
    
    def _assess_severity(self, p_mastery, node):
        if p_mastery < 0.40 and node.is_core:
            return "critical"
        elif p_mastery < 0.60:
            return "moderate"
        elif p_mastery < 0.80:
            return "minor"
        else:
            return "none"
    
    def _action_for_severity(self, severity, node):
        mapping = {
            "critical": "jump_to_micro + assault_mode",
            "moderate": "soft_hint + continue",
            "minor": "log_only + post_scene_review",
            "none": "continue"
        }
        return mapping[severity]
```

---

## 动机检测

```python
class MotivationDetector:
    """
    从行为数据推断动机状态
    """
    
    def assess(self, learner_state, recent_records):
        
        signals = {}
        
        # 信号 1: 会话频率变化
        recent_freq = sessions_per_week(last_2_weeks)
        historical_freq = sessions_per_week(all_time)
        signals["freq_trend"] = recent_freq / max(historical_freq, 0.1)
        
        # 信号 2: 犹豫时间趋势
        signals["hesitation_trend"] = (
            recent_records.avg_hesitation - learner_state.baseline_hesitation
        ) / learner_state.baseline_hesitation
        
        # 信号 3: 跳过/求助比例
        signals["skip_rate"] = recent_records.skips / recent_records.total
        
        # 信号 4: 主动探索行为（非强制路径的跳转）
        signals["exploration_index"] = recent_records.voluntary_explorations
        
        # 综合评分
        motivation_index = (
            0.35 * (1 - abs(signals["freq_trend"] - 1)) +  # 频率稳定 = 好
            0.25 * (1 - max(0, signals["hesitation_trend"])) +  # 犹豫减少 = 好
            0.25 * (1 - signals["skip_rate"]) +                 # 跳过少 = 好
            0.15 * signals["exploration_index"]                 # 主动探索 = 好
        )
        
        # Dropout 风险
        dropout_risk = 0.0
        if signals["freq_trend"] < 0.3:
            dropout_risk += 0.4
        if signals["skip_rate"] > 0.5:
            dropout_risk += 0.3
        if signals["hesitation_trend"] > 0.5:
            dropout_risk += 0.3
        
        return MotivationReport(
            index=motivation_index,
            dropout_risk=dropout_risk,
            signals=signals
        )
```

---

## DiagnosisReport 完整结构

```yaml
DiagnosisReport:
  timestamp: datetime
  trigger: "decision_point" | "quiz_completed" | "periodic_check"
  
  knowledge_gaps:
    - node_id: string
      p_mastery: float
      severity: critical | moderate | minor
      attribution: concept | calculation | comprehension | prerequisite
      prerequisite_gap: string | null
      evidence: [PerformanceRecord]
      
  overall_learner_state:
    avg_mastery: float
    mastered_count: int
    total_count: int
    current_zone: comfort | stretch | panic
    
  motivation:
    index: float
    dropout_risk: float
    recommendation: string  # "需要正向激励" | "需要降低难度" | "正常"
    
  spiral_status:
    nodes_ready_for_upgrade: [string]  # 掌握度够高但深度不够，可以螺旋升级
    nodes_needing_review: [string]     # 掌握度开始衰减，需要复习
```
