function config = pipeline_config()
%PIPELINE_CONFIG Returns a struct with all pipeline configuration
%
% Outputs:
%   config - struct containing configuration parameters for DrishtiSetu pipeline

addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

config = struct();
config.input_size = [1024 1024 3];
config.cnn_input_size = [512 512 3];
config.retina_diameter_target = 900;
config.clahe_clip_limit = 0.02;
config.quality_tile_grid = [4 4];
config.quality_sharpness_threshold = 100;
config.quality_illumination_range = [40 220];
config.max_retake_attempts = 3;
config.patch_size = 256;
config.patch_stride = 192;
config.unet_bg_threshold = 0.95;
config.pref_band = struct('low', 0.15, 'high', 0.85);
config.T_values = [1.0, 1.0];
config.ood_jsd_threshold = 0.5;
config.ood_conf_threshold = 0.40;
config.dme_pixel_threshold = 50;
config.concordance_min_lesions_for_high_grade = 5;
config.concordance_max_lesions_for_grade0 = 20;
config.leak_rate_cap = 0.10;
config.model_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'models');
config.icdr_labels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};
config.icdr_hindi = {'सामान्य', 'हल्का', 'मध्यम', 'गंभीर', 'अत्यंत गंभीर'};
config.urgency_labels = {'Annual screening', 'Follow-up in 6 months', 'Refer within 3 months', 'Refer within 2 weeks', 'Immediate referral'};

% Try to load overrides from models directory
t_values_file = fullfile(config.model_dir, 'T_values.mat');
if isfile(t_values_file)
    try
        t_data = load(t_values_file);
        if isfield(t_data, 'T_values')
            config.T_values = t_data.T_values;
        end
    catch
        warning('Failed to load T_values.mat');
    end
end

pref_band_file = fullfile(config.model_dir, 'pref_band.mat');
if isfile(pref_band_file)
    try
        pref_data = load(pref_band_file);
        if isfield(pref_data, 'pref_band')
            config.pref_band = pref_data.pref_band;
        end
    catch
        warning('Failed to load pref_band.mat');
    end
end

end
