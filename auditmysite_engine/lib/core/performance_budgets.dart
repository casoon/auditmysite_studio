/// Performance Budget Templates aligned with original AuditMySite NPM tool
class PerformanceBudget {
  final String name;
  final String description;
  final Map<String, BudgetThreshold> thresholds;
  
  const PerformanceBudget({
    required this.name,
    required this.description,
    required this.thresholds,
  });

  /// Check if a metric passes the budget
  bool checkMetric(String metric, double value) {
    final threshold = thresholds[metric];
    if (threshold == null) return true;
    return value <= threshold.maxValue;
  }

  /// Calculate score based on budget compliance
  double calculateScore(Map<String, double> metrics) {
    if (thresholds.isEmpty) return 100.0;
    
    double totalScore = 0;
    int count = 0;
    
    thresholds.forEach((metric, threshold) {
      final value = metrics[metric];
      if (value != null) {
        final score = threshold.calculateScore(value);
        totalScore += score;
        count++;
      }
    });
    
    return count > 0 ? totalScore / count : 100.0;
  }

  /// Get letter grade based on performance
  String getGrade(Map<String, double> metrics) {
    final score = calculateScore(metrics);
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'thresholds': thresholds.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class BudgetThreshold {
  final double goodValue;    // Excellent performance
  final double needsWorkValue; // Acceptable performance
  final double maxValue;      // Maximum acceptable value
  final String unit;
  final double weight;        // Importance weight (0-1)

  const BudgetThreshold({
    required this.goodValue,
    required this.needsWorkValue,
    required this.maxValue,
    this.unit = 'ms',
    this.weight = 1.0,
  });

  /// Calculate score for a given value (0-100)
  double calculateScore(double value) {
    if (value <= goodValue) {
      return 100.0;
    } else if (value <= needsWorkValue) {
      // Linear interpolation between good and needs work
      final range = needsWorkValue - goodValue;
      final position = value - goodValue;
      return 100 - (position / range * 30); // 100 to 70
    } else if (value <= maxValue) {
      // Linear interpolation between needs work and max
      final range = maxValue - needsWorkValue;
      final position = value - needsWorkValue;
      return 70 - (position / range * 40); // 70 to 30
    } else {
      // Beyond max, exponential decay
      final excess = value - maxValue;
      final penaltyRate = excess / maxValue;
      return (30 * Math.exp(-penaltyRate)).clamp(0, 30);
    }
  }

  Map<String, dynamic> toJson() => {
    'good': goodValue,
    'needsWork': needsWorkValue,
    'max': maxValue,
    'unit': unit,
    'weight': weight,
  };
}

/// Predefined performance budget templates
class PerformanceBudgets {
  /// Default budget - Google Web Vitals Standard
  static const PerformanceBudget defaultBudget = PerformanceBudget(
    name: 'default',
    description: 'Google Web Vitals Standard - Recommended baseline for all websites',
    thresholds: {
      'lcp': BudgetThreshold(
        goodValue: 2500,
        needsWorkValue: 4000,
        maxValue: 6000,
        unit: 'ms',
      ),
      'fcp': BudgetThreshold(
        goodValue: 1800,
        needsWorkValue: 3000,
        maxValue: 4500,
        unit: 'ms',
      ),
      'cls': BudgetThreshold(
        goodValue: 0.1,
        needsWorkValue: 0.25,
        maxValue: 0.5,
        unit: 'score',
      ),
      'inp': BudgetThreshold(
        goodValue: 200,
        needsWorkValue: 500,
        maxValue: 1000,
        unit: 'ms',
      ),
      'ttfb': BudgetThreshold(
        goodValue: 800,
        needsWorkValue: 1800,
        maxValue: 3000,
        unit: 'ms',
      ),
      'tbt': BudgetThreshold(
        goodValue: 200,
        needsWorkValue: 600,
        maxValue: 1500,
        unit: 'ms',
      ),
    },
  );

  /// E-commerce budget - Conversion optimized
  static const PerformanceBudget ecommerceBudget = PerformanceBudget(
    name: 'ecommerce',
    description: 'E-commerce Optimized - Strict thresholds for shopping experiences and conversion rates',
    thresholds: {
      'lcp': BudgetThreshold(
        goodValue: 2000,
        needsWorkValue: 3000,
        maxValue: 4000,
        unit: 'ms',
        weight: 1.2,
      ),
      'fcp': BudgetThreshold(
        goodValue: 1500,
        needsWorkValue: 2500,
        maxValue: 3500,
        unit: 'ms',
        weight: 1.1,
      ),
      'cls': BudgetThreshold(
        goodValue: 0.05,
        needsWorkValue: 0.1,
        maxValue: 0.25,
        unit: 'score',
        weight: 1.3,
      ),
      'inp': BudgetThreshold(
        goodValue: 150,
        needsWorkValue: 300,
        maxValue: 500,
        unit: 'ms',
        weight: 1.2,
      ),
      'ttfb': BudgetThreshold(
        goodValue: 600,
        needsWorkValue: 1200,
        maxValue: 2000,
        unit: 'ms',
        weight: 1.1,
      ),
      'tbt': BudgetThreshold(
        goodValue: 150,
        needsWorkValue: 350,
        maxValue: 600,
        unit: 'ms',
        weight: 1.2,
      ),
    },
  );

  /// Corporate budget - Professional standards
  static const PerformanceBudget corporateBudget = PerformanceBudget(
    name: 'corporate',
    description: 'Corporate Standards - Balanced for business websites and professional services',
    thresholds: {
      'lcp': BudgetThreshold(
        goodValue: 2500,
        needsWorkValue: 4000,
        maxValue: 5500,
        unit: 'ms',
      ),
      'fcp': BudgetThreshold(
        goodValue: 1800,
        needsWorkValue: 3000,
        maxValue: 4000,
        unit: 'ms',
      ),
      'cls': BudgetThreshold(
        goodValue: 0.1,
        needsWorkValue: 0.25,
        maxValue: 0.4,
        unit: 'score',
      ),
      'inp': BudgetThreshold(
        goodValue: 200,
        needsWorkValue: 500,
        maxValue: 800,
        unit: 'ms',
      ),
      'ttfb': BudgetThreshold(
        goodValue: 800,
        needsWorkValue: 1800,
        maxValue: 2500,
        unit: 'ms',
      ),
      'tbt': BudgetThreshold(
        goodValue: 200,
        needsWorkValue: 600,
        maxValue: 1200,
        unit: 'ms',
      ),
    },
  );

  /// Blog budget - Content focused
  static const PerformanceBudget blogBudget = PerformanceBudget(
    name: 'blog',
    description: 'Blog/Content Optimized - Relaxed thresholds for content consumption and reading experience',
    thresholds: {
      'lcp': BudgetThreshold(
        goodValue: 3000,
        needsWorkValue: 4500,
        maxValue: 6000,
        unit: 'ms',
        weight: 0.9,
      ),
      'fcp': BudgetThreshold(
        goodValue: 2000,
        needsWorkValue: 3500,
        maxValue: 5000,
        unit: 'ms',
        weight: 0.9,
      ),
      'cls': BudgetThreshold(
        goodValue: 0.1,
        needsWorkValue: 0.25,
        maxValue: 0.5,
        unit: 'score',
        weight: 1.1,
      ),
      'inp': BudgetThreshold(
        goodValue: 300,
        needsWorkValue: 600,
        maxValue: 1000,
        unit: 'ms',
        weight: 0.8,
      ),
      'ttfb': BudgetThreshold(
        goodValue: 1000,
        needsWorkValue: 2000,
        maxValue: 3500,
        unit: 'ms',
        weight: 0.9,
      ),
      'tbt': BudgetThreshold(
        goodValue: 300,
        needsWorkValue: 800,
        maxValue: 1500,
        unit: 'ms',
        weight: 0.8,
      ),
    },
  );

  /// Get budget by name
  static PerformanceBudget getBudget(String name) {
    switch (name.toLowerCase()) {
      case 'ecommerce':
      case 'e-commerce':
        return ecommerceBudget;
      case 'corporate':
      case 'business':
        return corporateBudget;
      case 'blog':
      case 'content':
        return blogBudget;
      case 'default':
      default:
        return defaultBudget;
    }
  }

  /// Get all available budgets
  static List<PerformanceBudget> getAllBudgets() {
    return [
      defaultBudget,
      ecommerceBudget,
      corporateBudget,
      blogBudget,
    ];
  }

  /// Compare performance against a budget
  static Map<String, dynamic> analyzeBudgetCompliance(
    Map<String, double> metrics,
    PerformanceBudget budget,
  ) {
    final results = <String, dynamic>{};
    
    budget.thresholds.forEach((metric, threshold) {
      final value = metrics[metric];
      if (value != null) {
        final score = threshold.calculateScore(value);
        final status = value <= threshold.goodValue ? 'good' :
                      value <= threshold.needsWorkValue ? 'needs-improvement' :
                      value <= threshold.maxValue ? 'poor' : 'failing';
        
        results[metric] = {
          'value': value,
          'score': score,
          'status': status,
          'threshold': {
            'good': threshold.goodValue,
            'needsWork': threshold.needsWorkValue,
            'max': threshold.maxValue,
          },
          'unit': threshold.unit,
          'passes': value <= threshold.maxValue,
        };
      }
    });
    
    final overallScore = budget.calculateScore(metrics);
    final grade = budget.getGrade(metrics);
    
    return {
      'budget': budget.name,
      'metrics': results,
      'overallScore': overallScore,
      'grade': grade,
      'passes': results.values.every((r) => r['passes'] == true),
    };
  }
}

// Helper class for math operations
class Math {
  static double exp(double x) {
    // Simple exponential approximation
    if (x == 0) return 1;
    if (x < 0) return 1 / exp(-x);
    
    double result = 1;
    double term = 1;
    for (int i = 1; i < 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }
}