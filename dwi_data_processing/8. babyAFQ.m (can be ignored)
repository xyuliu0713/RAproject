%% ============================
% babyAFQ pipeline
% ============================
addpath(genpath('/Users/molin/Downloads/apps/AFQ-master/babyAFQ'));
addpath(genpath('/Users/molin/Downloads/apps/vistasoft'));
addpath('/Users/molin/Downloads/apps/vistasoft/mrDiffusion');
addpath('/Users/molin/Downloads/apps/spm12');
setenv('PATH', ['/opt/miniconda3/bin:' getenv('PATH')]);

sub_ids = {'sub-01'};

ses_ids = {'ses-03'};

raw_base_dir = '/Volumes/xyu/files/ds006169-2';

afq_base_dir = '/Volumes/xyu/files/AFQ_baby';

for i = 1:length(sub_ids)

    for s = 1:length(ses_ids)

        sub_id = sub_ids{i};

        ses_id = ses_ids{s};

        disp(['>>> babyAFQ: ', sub_id, ' | ', ses_id]);

        %% ============================
        % 输入路径（BIDS）
        % ============================
        dwi_dir  = fullfile(raw_base_dir, sub_id, ses_id, 'dwi');
        anat_dir = fullfile(raw_base_dir, sub_id, ses_id, 'anat');
        
        dwi_file  = fullfile(dwi_dir,  'dwi_preproc.nii.gz');
        bvec_file = fullfile(dwi_dir,  'dwi_preproc.bvec');
        bval_file = fullfile(dwi_dir,  'dwi_preproc.bval');
        
        t1_file   = fullfile(anat_dir, [sub_id '_' ses_id '_T1w.nii.gz']);
        
        %% ============================
        % 输出路径（带 session）
        % ============================
        sub_out_dir = fullfile(afq_base_dir, sub_id, ses_id);
        out_dti_dir = fullfile(sub_out_dir, 'dti');
        fibers_dir  = fullfile(sub_out_dir, 'fibers');
        
        if ~exist(out_dti_dir, 'dir'), mkdir(out_dti_dir); end
        if ~exist(fibers_dir, 'dir'), mkdir(fibers_dir); end
        %% ============================

        % Step 1: dtiInit（保留）

        %% ============================

        % params = dtiInitParams;
        % 
        % params.outDir = fullfile(out_dir, 'dti');
        % 
        % params.bvecsFile = bvec_file;
        % 
        % params.bvalsFile = bval_file;
        % 
        % params.clobber = true;
        % 
        % params.motionComp = 0;
        % 
        % params.eddyCorrect = 0;
        % 
        % params.rohdeEddyCorrect = 0;


        params = dtiInitParams;
        params.coreg = 0;  % 或者关闭可视化
        params.outDir = fullfile(out_dir, 'dti');
        params.bvecsFile      = bvec_file;
        params.bvalsFile      = bval_file;
        params.phaseEncodeDir = 2;
        % params.dwOutMm        = [2 2 2];
        params.clobber        = true;
        params.showFibers     = false;
        params.batchMode      = true;
        params.motionComp = 0;        % 🚨 关闭 motion correction
        params.eddyCorrect = 0;       % 🚨 关闭 eddy correction
        params.rohdeEddyCorrect = 0;  % 🚨 关键！关闭 Rohde（就是现在炸的这个）


        [dt6, outBaseDir] = dtiInit(dwi_file, t1_file, params);

        disp('✅ dt6 done');

        %% ============================
        % Step 2: 复制 dt6 和 bin（⚠️ AFQ 必须）
        % ============================
        dt6_src = fullfile(out_dti_dir, 'dti30trilin', 'dt6.mat');
        bin_src = fullfile(out_dti_dir, 'dti30trilin', 'bin');
        
        dt6_dst = fullfile(sub_out_dir, 'dt6.mat');
        bin_dst = fullfile(sub_out_dir, 'bin');
        
        copyfile(dt6_src, dt6_dst);
        copyfile(bin_src, bin_dst);
        
        disp('✅ dt6.mat 和 bin 已复制到 subject 根目录');
        %% ============================

        % Step 3: babyAFQ（关键）

        %% ============================
        afq = AFQ_Create(...
            out_dir, ...
            'bids', 0, ...
            'baby', 1, ...
            'clobber', 1, ...       
            'doTractography', true, ...
            'doSegmentation', true, ...
            'doProfiles', true, ...
            'cleanFibers', true, ...        
            'numberOfNodes', 100 ...       
        );

        save(fullfile(out_dir,'afq_baby.mat'),'afq','-v7.3');

        disp(['✅ babyAFQ 完成: ', sub_id]);

    end

end