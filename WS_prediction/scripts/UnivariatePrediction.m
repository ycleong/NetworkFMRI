%% Univariate Prediction
% YC Leong 7/17/2017 
% This scripts takes in beta maps associated which each hub category of all 50 participants, and 
% averages the beta maps to predict hub category following a leave-one-participant-out 
% cross-validation procedure.
% 
% Parameters:
%   run_regression: 1 = run the regression analyses, 0 skip the regression analyses and go to
%   summary figures
%   explained_threshold = cumulative % of variance explained of retained components 
% 
% Outputs: For each ROI, generates a .mat file containing the predicted Hub category over all cross-
% validation iterations.
%
% Dependencies:
%   CANlabCore Toolbox available at https://github.com/canlab/CanlabCore
%   NifTI toolbox available at 
%        https://www.mathworks.com/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image
%   SPM available at http://www.fil.ion.ucl.ac.uk/spm/

clear all
run_regression = 1;
run_FC = 0;
font_size = 24;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                             Setup                                                % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add Toolboxes
addpath(genpath('../../../CanlabCore')) 
addpath(genpath('../../../NIfTI')) 
addpath(genpath('/Users/yuanchangleong/Documents/spm12'))


% Set Directories 
dirs.data = '../glm';
dirs.mask = '../../masks';
dirs.results = '../../results';
dirs.input = fullfile(dirs.data,'faces60_tmap');
dirs.output = fullfile(dirs.results,'Univariate_WS');

% Make output directory if it doesn't exist
if ~exist(dirs.output)
    mkdir(dirs.output);
end

% ROI Information 
mask_files = {'mentalizing.nii','MPFCswath.nii','PrecunPCC.nii',...
    'RTempPoles.nii','LTempPoles.nii','RTPJ.nii','LTPJ.nii','BilatVS_Plus5Win5_Lose0.nii','V1.nii'};
nmask = length(mask_files);
mask_names = {'Mentalizing','MPFC','PMC','RTP','LTP','RTPJ','LTPJ','Striatum','V1'};

% Subject Information 
Subjects = load('../../data/subject_numbers.txt');
nSub = length(Subjects);

% number of bins
nbins = 3;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                            Regression                                                    % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if run_regression

% Loop over ROIs
for mm = 1
    this_mask = fullfile(dirs.mask,mask_files{1,mm});
    fprintf('Running ROI: %s \n', this_mask);
    
    clear AllResults
    
    % Get paths
    for s = 1
        
        % load data of this subject
        thisdat_path = fullfile(dirs.input,sprintf('subj%s_tmap.nii.gz',num2str(Subjects(s))));
        thisdata = fmri_data(thisdat_path,this_mask);
        
        % averavge over ROI
        thisdat.mean = mean(thisdata.dat);
        
        % construct Y matrix
        load(fullfile('../regmat',sprintf('%i_FacesIndegreeFactorCntrlBin.mat',Subjects(s))));
        thisdat.Y = [ones(length(indegreeT0_factor_cntrl_tertile1_onset),1) * 3;...
            ones(length(indegreeT0_factor_cntrl_tertile2_onset),1) * 2;...
            ones(length(indegreeT0_factor_cntrl_tertile3_onset),1)];
        
        TrialID = [1:60];
        
        stats.yfit = [];
        stats.Y = thisdat.Y;
        
        for t = 1:length(TrialID)
            train_data = thisdat.mean(TrialID ~= t)';
            train_y = thisdat.Y(TrialID ~= t);
            
            % Format training dataset
            train_set = table(train_y, train_data,'VariableNames',{'Y','data'});
            
            % Train model
            trained_model = fitlm(train_set,'Y~data');
            
            % Testing set
            test_data = thisdat.mean(TrialID == t)';
            test_y = thisdat.Y(TrialID == t);
            
            % Format Testing set
            test_set = table(test_y, test_data,'VariableNames',{'Y','data'});
            
            % Test data
            this_ypred = predict(trained_model, test_set);

            stats.yfit = [stats.yfit; this_ypred];
            
        end
        
        AllResults{s,1}.Predicted = stats.yfit;
        AllResults{s,1}.Y = stats.Y;
        
    end
    
    save(sprintf('%s.mat',fullfile(dirs.output,mask_files{1,mm}(1:end-4))),...
        'AllResults');
  
end

end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %                                Compute Forced-Choice Accuracy                                    %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if run_FC

Combos = combnk([1:60],2); % 60 Choose 2

for mm = 1
    
    this_mask = fullfile(dirs.mask,mask_files{1,mm});
    fprintf('Running ROI: %s \n', this_mask);
    
    AllFC = NaN(nSub,3);
    
    for s = 1:nSub
        % fprintf('Running subject %i \n', Subjects(s));
        
        load(sprintf('%s.mat',fullfile(dirs.output,mask_files{1,mm}(1:end-4))));
        
        thisResult = AllResults{s,1};
        
        MedVsLow = [];
        MedVsHigh = [];
        HighVsLow = [];
        
        for c = 1:length(Combos)
            Y1 = thisResult.Y(Combos(c,1));
            Y2 = thisResult.Y(Combos(c,2));
            P1 = thisResult.Predicted(Combos(c,1));
            P2 = thisResult.Predicted(Combos(c,2));
            
            if P1 > P2 % Correct
                if (Y1 == 2) && (Y2 == 1) % MedVsLow 
                    MedVsLow = [MedVsLow; 1]; 
                elseif (Y1 == 3) && (Y2 == 2) % MedVsHigh
                    MedVsHigh = [MedVsHigh; 1];                  
                elseif (Y1 == 3) && (Y2 == 1) %HighVsLow
                    HighVsLow = [HighVsLow; 1];
                end
            else
                if (Y1 == 2) && (Y2 == 1) % MedVsLow
                    MedVsLow = [MedVsLow; 0];
                elseif (Y1 == 3) && (Y2 == 2) % MedVsHigh
                    MedVsHigh = [MedVsHigh; 0];
                elseif (Y1 == 3) && (Y2 == 1) %HighVsLow
                    HighVsLow = [HighVsLow; 0];
                end
            end
        end
        
        AllFC(s,1) = mean(MedVsLow);
        AllFC(s,2) = mean(MedVsHigh);
        AllFC(s,3) = mean(HighVsLow);
    end
    
    mean(AllFC)
    
    save(sprintf('%s_AllFC.mat',fullfile(dirs.output,mask_files{1,mm}(1:end-4))),...
        'AllFC');
    
end

end

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %                                   Plot Forced-Choice Accuracy                                    %
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for mm = 1:nmask
    load(sprintf('%s_AllFC.mat',fullfile(dirs.output,mask_files{1,mm}(1:end-4))));
    
    FC(mm,:) = mean(AllFC);
    FC_err(mm,:) = std(AllFC)/sqrt(nSub);
    
    for t = 1:3
        [FC_h(mm,t)] = ttest(AllFC(:,t),0.5);      
    end
    
end

% % Intialize Figure
fig = figure();
hold on
set(gcf,'Position',[100 100 1000 400]);

% Setup plot
y = reshape(FC',1,27);
x = [1,2,3,5,6,7,9,10,11,13,14,15,17,18,19,21,22,23,25,26,27,29,30,31,33,34,35];

% Color for mentalizing ROIs
bar_col = [203,24,29;   % 3rd
    252,174,145;        % 1st 
    251,106,74];        % 2nd

% Color for VS
bar_col2 = [33,113,181;
    189,215,231;
    107,174,214];

% Color for V1
bar_col3 = [0.5,0.5,0.5;
    0.9,0.9,0.9;
    0.7,0.7,0.7];

bar_col = bar_col/255;
bar_col2 = bar_col2/255;

% Plot mentalizing ROIs
for i = 1:21
    b = bar(x(i),y(i),0.7);
    this_col = mod(i,3)+1;
    set(b,'facecolor',bar_col(this_col,:))
end

% Plot VS
for i = 22:24
    b = bar(x(i),y(i),0.7);
    this_col = mod(i,3)+1;
    set(b,'facecolor',bar_col2(this_col,:))
end

% Plot V1
for i = 25:27
    b = bar(x(i),y(i),0.7);
    this_col = mod(i,3)+1;
    set(b,'facecolor',bar_col3(this_col,:))
end

% Plot error bars
h = errorbar(x,y,reshape(FC_err',1,27));
set(h,'Color',[0,0,0],'linestyle','none');

% Chance line
plot([0,36],[0.5,0.5],'Color','k','LineStyle','--','LineWidth',2);

% Adjust axis
ylabel('Forced Choice Accuracy');
set(gca,'xtick',[2,6,10,14,18,22,26,30,34],'xticklabel',mask_names)
set(gca,'ytick',[0:0.25:1]);
 
% % Run and plot t Test Results
sig = x(logical(reshape(FC_h',nmask*3,1)));
scatter(sig,repmat(0.95,1,length(sig)),30,'k','*');

axis([0 36 0 1]);
set(gca,'FontSize',20)
  
% % Save Figure
fig_dest = fullfile(dirs.output,sprintf('ForcedChoiceAcc'));
set(gcf,'paperpositionmode','auto');
print(fig,'-depsc',fig_dest);

