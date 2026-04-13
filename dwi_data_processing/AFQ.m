%% ============================
% 自动 DWI -> dt6 -> Tractography -> AFQ
% =============================

addpath(genpath('/Users/molin/Downloads/apps/AFQ-master'));
addpath(genpath('/Users/molin/Downloads/MSc neuroimaging/neuroimaging P4/P4exam-6 data/vistasoft'));

% ============================
% 设置路径
% ============================
sub_dirs = {'/Volumes/xyu/files/pyAFQ_dataset/sub-02/ses-01'};
for i = 1:length(sub_dirs)
    sub_dir = sub_dirs{i};
    dwi_file = fullfile(sub_dir, 'dwi', 'sub-02_ses-01_dwi.nii.gz');
    bvec_file = fullfile(sub_dir, 'dwi', 'sub-02_ses-01_dwi.bvec');
    bval_file = fullfile(sub_dir, 'dwi', 'sub-02_ses-01_dwi.bval');

    out_dir = fullfile('/Volumes/xyu/files/AFQ_matlab', 'sub-02', 'dti');
    fibers_dir = fullfile('/Volumes/xyu/files/AFQ_matlab', 'sub-02', 'fibers');
    mkdir(out_dir); mkdir(fibers_dir);

    %% ============================
    % Step 1: DTI 初始化 -> dt6.mat
    %% ============================
    dt6 = dtiInit(dwi_file, 'bvecsFile', bvec_file, 'bvalsFile', bval_file, ...
                  'outDir', out_dir);
    disp('✅ dt6.mat 已生成');

    %% ============================
    % Step 2: 全脑纤维追踪 -> WholeBrainFG.mat
    %% ============================
    fg = dtiFiberTrack(dt6);
    save(fullfile(fibers_dir, 'WholeBrainFG.mat'), 'fg');
    disp('✅ WholeBrainFG.mat 已生成');

    %% ============================
    % Step 3: 运行 AFQ
    %% ============================
    afq = AFQ_Create('sub_dirs', {fullfile('/Volumes/xyu/files/AFQ_matlab', 'sub-02')});
    afq = AFQ_run({fullfile('/Volumes/xyu/files/AFQ_matlab', 'sub-02')}, afq);
    disp('✅ AFQ 分析完成');
end