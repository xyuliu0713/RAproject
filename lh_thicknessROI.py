import pandas as pd
import os

# 设置路径
os.chdir("/Users/molin/Downloads/ds006169-test/toddler_fs_subjects")

# 读文件（改成 thickness）
df = pd.read_csv("lh_thickness.txt", sep=r"\s+")

# 第一列改名为 subject
df.rename(columns={df.columns[0]: "subject"}, inplace=True)

# 需要的ROI（全部改成 _thickness）
cols = [
    "subject",
    "lh_bankssts_thickness",
    "lh_fusiform_thickness",
    "lh_inferiorparietal_thickness",
    "lh_middletemporal_thickness",
    "lh_parsopercularis_thickness",
    "lh_parstriangularis_thickness",
    "lh_superiortemporal_thickness",
    "lh_supramarginal_thickness"
]

# 筛选
df_roi = df[cols]

# 保存
df_roi.to_csv("lh_thickness_ROI.csv", index=False)

print("✅ 成功！（thickness）")
print(df_roi.head())