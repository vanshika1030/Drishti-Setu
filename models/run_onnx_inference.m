function [result] = run_onnx_inference(model_type, image_path, model_path)
%RUN_ONNX_INFERENCE Run ONNX model inference via Python onnxruntime.
%
%   result = RUN_ONNX_INFERENCE(model_type, image_path, model_path)
%
%   Calls the Python onnx_inference.py script which uses onnxruntime
%   for reliable ONNX model inference. Results are passed back via .mat file.
%
%   Inputs:
%     model_type  - 'dr', 'vessel', or 'lesion'
%     image_path  - Absolute path to the input image file
%     model_path  - Absolute path to the .onnx model file
%
%   Outputs:
%     result      - Struct with inference results, or empty if failed
%                   result.success = true/false

    result = struct('success', false);
    
    % Locate the Python inference script (same directory as this function)
    script_dir = fileparts(mfilename('fullpath'));
    py_script = fullfile(script_dir, 'onnx_inference.py');
    
    if ~exist(py_script, 'file')
        warning('onnx_inference.py not found at: %s', py_script);
        return;
    end
    
    % Create temp output file
    output_mat = fullfile(tempdir, sprintf('onnx_result_%s_%d.mat', model_type, round(now*1e6)));
    
    % Build command
    cmd = sprintf('python "%s" %s "%s" "%s" "%s"', ...
        py_script, model_type, image_path, model_path, output_mat);
    
    % Pre-flight: Check for external data files that some ONNX models need
    % (e.g., drive_vessel_unet.onnx requires drive_vessel_unet.onnx.data)
    external_data = [model_path '.data'];
    if exist(external_data, 'file') == 0
        % Quick check: does the model reference external data?
        finfo = dir(model_path);
        if finfo.bytes < 500000  % Models under 500KB likely use external data
            warning('ONNX model %s is small (%.1f KB) and may need external data file: %s', ...
                model_path, finfo.bytes/1024, external_data);
            fprintf('  -> External data file not found. Falling back to classical method.\n');
            return;
        end
    end
    
    fprintf('Running ONNX inference via Python: %s\n', model_type);
    [status, cmdout] = system(cmd);
    
    if status ~= 0
        warning('Python ONNX inference failed (exit code %d):\n%s', status, cmdout);
        % Try cleaning up
        if exist(output_mat, 'file')
            try
                result = load(output_mat);
            catch
            end
            delete(output_mat);
        end
        return;
    end
    
    % Display Python output
    if ~isempty(cmdout)
        fprintf('%s\n', strtrim(cmdout));
    end
    
    % Load results
    if exist(output_mat, 'file')
        result = load(output_mat);
        delete(output_mat);
    else
        warning('ONNX output file not created: %s', output_mat);
    end
end
