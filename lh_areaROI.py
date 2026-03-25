import pandas as pd
import os

# 设置路径
os.chdir("/Users/molin/Downloads/ds006169-test/toddler_fs_subjects")

# 读文件（改成 area）
df = pd.read_csv("lh_area.txt", sep=r"\s+")

# 第一列改名为 subject
df.rename(columns={df.columns[0]: "subject"}, inplace=True)

# 需要的ROI（全部改成 _area）
cols = [
    "subject",
    "lh_bankssts_area",
    "lh_fusiform_area",
    "lh_inferiorparietal_area",
    "lh_middletemporal_area",
    "lh_parsopercularis_area",
    "lh_parstriangularis_area",
    "lh_superiortemporal_area",
    "lh_supramarginal_area"
]

# 筛选
df_roi = df[cols]

# 保存
df_roi.to_csv("lh_area_ROI.csv", index=False)

print("✅ 成功！（area）")
print(df_roi.head())