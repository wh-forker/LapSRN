function evaluate_LapSRN_dataset(model_scale, dataset, test_scale, gpu)
    
    if( ~exist('gpu', 'var') )
        gpu = 1;
    end
    
    if( test_scale < model_scale )
        error('Test scale must be greater than or equal to model scale (%d vs %d)', ...
            test_scale, model_scale);
    end
    
    opts.gpu = gpu;
    opts.scale = test_scale;
    
    
    %% setup paths
    input_dir = fullfile('datasets', dataset, 'GT');
    output_dir = fullfile('results', dataset, sprintf('x%d', test_scale), ...
                 sprintf('LapSRN_x%d', model_scale));

    if( ~exist(output_dir, 'dir') )
        mkdir(output_dir);
    end
    
    addpath(genpath('utils'));
    addpath(fullfile(pwd, 'matconvnet-1.0-beta24/matlab'));
    vl_setupnn;
    
    %% load model
    model_filename = fullfile('pretrained_models', sprintf('LapSRN_x%d.mat', model_scale));
    
    fprintf('Load %s\n', model_filename);
    net = load(model_filename);
    net = dagnn.DagNN.loadobj(net.net);
    net.mode = 'test' ;

    if( opts.gpu ~= 0 )
        gpuDevice(opts.gpu)
        net.move('gpu');
    end
    
    %% load image list
    list_filename = fullfile('lists', sprintf('%s.txt', dataset));
    img_list = load_list(list_filename);
    num_img = length(img_list);

    
    %% testing
    PSNR = zeros(num_img, 1);
    SSIM = zeros(num_img, 1);
    IFC  = zeros(num_img, 1);
    
    for i = 1:num_img

        img_name = img_list{i};
        fprintf('Process %s %d/%d: %s\n', dataset, i, num_img, img_name);
        
        % Load GT image
        input_filename = fullfile(input_dir, sprintf('%s.png', img_name));
        img_GT = im2double(imread(input_filename));
        img_GT = mod_crop(img_GT, test_scale);
        
        % generate LR image
        img_LR = imresize(img_GT, 1/test_scale, 'bicubic');
            
        % apply LapSRN
        img_HR = SR_LapSRN(img_LR, net, opts);
            
        % save result
        output_filename = fullfile(output_dir, sprintf('%s.png', img_name));
        fprintf('Save %s\n', output_filename);
        imwrite(img_HR, output_filename);
            
        %% evaluate
        img_HR = im2double(im2uint8(img_HR)); % quantize pixel values
        
        % convert to gray scale
        img_GT = rgb2ycbcr(img_GT); img_GT = img_GT(:, :, 1);
        img_HR = rgb2ycbcr(img_HR); img_HR = img_HR(:, :, 1);
        
        % crop boundary
        img_GT = shave_bd(img_GT, test_scale);
        img_HR = shave_bd(img_HR, test_scale);
        
        % evaluate
        PSNR(i) = psnr(img_GT, img_HR);
        SSIM(i) = ssim(img_GT, img_HR);
        
        IFC(i) = ifcvec(img_GT, img_HR);
        if( ~isreal(IFC(i)) )
            IFC(i) = 0;
        end

    end
    
    PSNR(end+1) = mean(PSNR);
    SSIM(end+1) = mean(SSIM);
    IFC(end+1)  = mean(IFC);
    
    fprintf('Average PSNR = %f\n', PSNR(end));
    fprintf('Average SSIM = %f\n', SSIM(end));
    fprintf('Average IFC = %f\n', IFC(end));
    
    filename = fullfile(output_dir, 'PSNR.txt');
    save_matrix(PSNR, filename);

    filename = fullfile(output_dir, 'SSIM.txt');
    save_matrix(SSIM, filename);
    
    filename = fullfile(output_dir, 'IFC.txt');
    save_matrix(IFC, filename);

