import pandas as pd
import os
os.chdir("/Users/molin/Downloads/ds006169-test/toddler_fs_subjects")  # 修改为你的数据目录

# 读文件
df = pd.read_csv("lh_volume.txt", sep=r"\s+")

# 🔥 关键：把第一列改名为 subject
df.rename(columns={df.columns[0]: "subject"}, inplace=True)

# 需要的ROI
cols = [
    "subject",
    "lh_bankssts_volume",
    "lh_fusiform_volume",
    "lh_inferiorparietal_volume",
    "lh_middletemporal_volume",
    "lh_parsopercularis_volume",
    "lh_parstriangularis_volume",
    "lh_superiortemporal_volume",
    "lh_supramarginal_volume"
]

# 筛选
df_roi = df[cols]

# 保存
df_roi.to_csv("lh_volume_ROI.csv", index=False)

print("✅ 成功！")
print(df_roi.head())