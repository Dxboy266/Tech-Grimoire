#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
快速生成100万条订单测试数据
用于MySQL专栏第7讲实战案例
"""

import random
from datetime import datetime, timedelta
import sys

# 配置参数
TOTAL_ROWS = 10_000_000  # 1000万条
BATCH_SIZE = 1_000_000   # 每100万条显示一次进度
OUTPUT_FILE = 'orders_data.csv'

# 数据范围
USER_ID_MIN = 1
USER_ID_MAX = 100_000
STATUS_VALUES = [0, 1, 2]  # 0待支付 1已支付 2已完成
AMOUNT_MIN = 1.0
AMOUNT_MAX = 1000.0
START_DATE = datetime(2025, 1, 1)
END_DATE = datetime(2025, 12, 31)
DAYS_RANGE = (END_DATE - START_DATE).days

def generate_csv():
    """生成CSV数据文件"""
    print(f"{'='*60}")
    print(f"开始生成 {TOTAL_ROWS:,} 条订单测试数据")
    print(f"输出文件: {OUTPUT_FILE}")
    print(f"时间范围: {START_DATE.date()} 到 {END_DATE.date()}")
    print(f"{'='*60}\n")
    
    try:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            for i in range(1, TOTAL_ROWS + 1):
                # 生成随机数据
                user_id = random.randint(USER_ID_MIN, USER_ID_MAX)
                status = random.choice(STATUS_VALUES)
                amount = round(random.uniform(AMOUNT_MIN, AMOUNT_MAX), 2)
                
                # 生成随机日期时间
                random_days = random.randint(0, DAYS_RANGE)
                random_seconds = random.randint(0, 86399)  # 0-23:59:59
                created_at = START_DATE + timedelta(days=random_days, seconds=random_seconds)
                created_at_str = created_at.strftime('%Y-%m-%d %H:%M:%S')
                
                # 写入CSV：user_id,status,amount,created_at
                f.write(f"{user_id},{status},{amount},{created_at_str}\n")
                
                # 显示进度
                if i % BATCH_SIZE == 0:
                    progress = i / TOTAL_ROWS * 100
                    print(f"进度: {i:>10,} / {TOTAL_ROWS:,} ({progress:>5.1f}%)")
        
        # 完成提示
        print(f"\n{'='*60}")
        print(f"✅ 数据生成完成！")
        print(f"文件: {OUTPUT_FILE}")
        print(f"行数: {TOTAL_ROWS:,}")
        
        # 计算文件大小
        import os
        file_size_mb = os.path.getsize(OUTPUT_FILE) / 1024 / 1024
        print(f"大小: {file_size_mb:.1f} MB")
        print(f"{'='*60}\n")
        
        print("下一步：使用Navicat导入向导或执行以下SQL")
        print("-" * 60)
        print(f"LOAD DATA LOCAL INFILE '{OUTPUT_FILE}'")
        print("INTO TABLE orders")
        print("FIELDS TERMINATED BY ','")
        print("LINES TERMINATED BY '\\n'")
        print("(user_id, status, amount, created_at);")
        print("-" * 60)
        
    except Exception as e:
        print(f"\n❌ 错误: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    generate_csv()
