import pandas as pd
import os

# 设置路径
os.chdir("/Users/molin/Downloads/ds006169-test/toddler_fs_subjects")

# 读文件（改成 meancurv）
df = pd.read_csv("lh_curv.txt", sep=r"\s+")

# 第一列改名为 subject
df.rename(columns={df.columns[0]: "subject"}, inplace=True)

# 需要的ROI（全部改成 _meancurv）
cols = [
    "subject",
    "lh_bankssts_meancurv",
    "lh_fusiform_meancurv",
    "lh_inferiorparietal_meancurv",
    "lh_middletemporal_meancurv",
    "lh_parsopercularis_meancurv",
    "lh_parstriangularis_meancurv",
    "lh_superiortemporal_meancurv",
    "lh_supramarginal_meancurv"
]

# 筛选
df_roi = df[cols]

# 保存
df_roi.to_csv("lh_meancurv_ROI.csv", index=False)

print("✅ 成功！（meancurv）")
print(df_roi.head())