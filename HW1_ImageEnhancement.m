%% =========================================================
% HW1: Image Enhancement
% Methods:
%   1. Piecewise Linear Contrast Stretching
%   2. AGCWD
%   3. SSR (Single-Scale Retinex)
%   4. Tone Mapping
%   5. Histogram Equalization (HE)
%   6. Gamma Correction
%
%% =========================================================

clear; clc; close all;

%% 1. Settings

inputFolder  = 'images';
outputFolder = 'results';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Save the whole command window output to a text file
logFile = fullfile(outputFolder, 'results_log.txt');
if exist(logFile, 'file')
    delete(logFile);
end
diary(logFile);


imageFiles = {
    'overexposed.jpg'
    'underexposed.jpg'
};


% Row 1: overexposed, Row 2: underexposed
isOverList = [true, false];

% 實驗參數設定(Row 1: overexposed, Row 2: underexposed)。

RUN_PARAMETER_TESTS = false;

% AGCWD 的 alpha 參數
agcwdAlphaList  = [0.7,  2.0];
% SSR 的高斯模糊尺度 sigma
ssrSigmaList    = [150,  150];
% SSR 的混合強度
ssrStrengthList = [0.5,  0.7];
% Tone Mapping 的 k 值
toneKList = [16,  10];    
% Gamma 校正參數
gammaList = [2.5, 0.5];  

% 參數測試開關。
RUN_PARAMETER_TESTS = false;

%各影像要測試參數

% AGCWD alpha
alphaTestAll    = {0.7,  2.0};
% SSR sigma
sigmaTestAll    = {150,  150};
% Tone Mapping k 
toneTestAll     = {16,   1000};
%Gamma 
gammaTestAll    = {2.5,  0.2};
% SSR strength 
strengthTestAll = {0.5,  0.7};

methodNames = {
    'Original'
    'Piecewise'
    'AGCWD'
    'SSR'
    'ToneMapping'
    'HE'
    'Gamma'
};


hasBRISQUE = exist('brisque', 'file') == 2;
hasNIQE    = exist('niqe', 'file') == 2;

if ~(hasBRISQUE && hasNIQE)
    fprintf(['Warning: BRISQUE / NIQE not found. ', ...
        'Check your installed MATLAB toolboxes.\n']);
end

%% 2. Process images

for n = 1:length(imageFiles)


    fileName  = imageFiles{n};
    inputPath = fullfile(inputFolder, fileName);

    if ~exist(inputPath, 'file')
        warning('Image not found: %s', inputPath);
        continue;
    end


    I = im2uint8(imread(inputPath));
    [~, baseName, ~] = fileparts(fileName);


    isOver     = isOverList(n);
    alpha      = agcwdAlphaList(n);
    sigma      = ssrSigmaList(n);
    strength   = ssrStrengthList(n);
    toneK      = toneKList(n);
    gammaValue = gammaList(n);


    alphaList     = alphaTestAll{n};
    sigmaList     = sigmaTestAll{n};
    toneTestList  = toneTestAll{n};
    gammaTestList = gammaTestAll{n};
    strengthTestList = strengthTestAll{n};

% 過曝影像先反相後套用部分增亮方法，最後再反相回來；欠曝影像則直接處理。
    if isOver
        suffix = ' [inverted]';
        modeText = 'overexposed (brightening methods run on inverted image)';
    else
        suffix = '';
        modeText = 'underexposed';
    end

    fprintf('\n====================================\n');
    fprintf('Image: %s  -> %s\n', fileName, modeText);
    fprintf('AGCWD alpha = %.2f\n', alpha);
    fprintf('SSR sigma = %g, strength = %.2f\n', sigma, strength);
    fprintf('Tone Mapping k = %.2f\n', toneK);
    fprintf('Gamma = %.2f\n', gammaValue);
    fprintf('====================================\n');

    %% 3. Apply enhancement methods

% 分段線性對比拉伸
    J_piece = piecewise_method(I);
% AGCWD
    J_agcwd = apply_enh(I, @(x) agcwd_method(x, alpha), isOver);
% SSR
    J_ssr   = apply_enh(I, @(x) ssr_method(x, sigma, strength), isOver);
% Tone Mapping
    J_tone  = apply_enh(I, @(x) tone_mapping_method(x, toneK), isOver);
% HE
    J_he    = he_method(I);
% Gamma
    J_gamma = gamma_method(I, gammaValue);

    %% 4. Save images and histograms separately


    blue   = [0.25 0.45 0.75];   % original
    orange = [0.85 0.45 0.25];   % enhanced

    save_outputs(I, 'Original', 'Original Histogram', ...
        baseName, outputFolder, blue);


    save_outputs(J_gamma, 'Gamma', ...
        sprintf('Gamma Correction (gamma = %.2f)', gammaValue), ...
        baseName, outputFolder, orange);


    save_outputs(J_he, 'HE', 'Histogram Equalization (HE)', ...
        baseName, outputFolder, orange);


    save_outputs(J_piece, 'Piecewise', ...
        'Piecewise Linear Contrast Stretching', ...
        baseName, outputFolder, orange);


    save_outputs(J_agcwd, 'AGCWD', ...
        sprintf('AGCWD (alpha = %.2f)%s', alpha, suffix), ...
        baseName, outputFolder, orange);

    save_outputs(J_ssr, 'SSR', ...
        sprintf('SSR (sigma = %g, strength = %.2f)%s', ...
        sigma, strength, suffix), ...
        baseName, outputFolder, orange);


    save_outputs(J_tone, 'ToneMapping', ...
        sprintf('Tone Mapping (k = %g)%s', toneK, suffix), ...
        baseName, outputFolder, orange);
%% 7. Overall visual comparison


    figCompare = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1600 800]);


    tiledlayout(figCompare, 2, 4, ...
        'TileSpacing', 'compact', 'Padding', 'compact');


    nexttile; imshow(I);       title('Original');
    nexttile; imshow(J_piece); title('Piecewise');
    nexttile; imshow(J_agcwd); title(sprintf('AGCWD (alpha = %.2f)', alpha));
    nexttile; imshow(J_ssr);   title(sprintf('SSR (\\sigma = %g, s = %.2f)', ...
                                      sigma, strength));
    nexttile; imshow(J_tone);  title(sprintf('Tone Mapping (k = %g)', toneK));
    nexttile; imshow(J_he);    title('HE');
    nexttile; imshow(J_gamma); title(sprintf('Gamma (%.2f)', gammaValue));

    exportgraphics(figCompare, fullfile(outputFolder, ...
        [baseName '_Overall_Comparison.png']), 'Resolution', 200);
    close(figCompare);

%% 8. Evaluation: Mean Gray, Entropy, BRISQUE, NIQE


    imagesToEvaluate = {I, J_piece, J_agcwd, J_ssr, J_tone, J_he, J_gamma};


    fprintf('\n%-12s %12s %12s %12s %12s\n', ...
        'Method', 'Mean Gray', 'Entropy', 'BRISQUE', 'NIQE');
    fprintf('%s\n', repmat('-', 1, 64));


    for k = 1:length(imagesToEvaluate)
        [m, e, b, q] = evaluate_image(imagesToEvaluate{k}, ...
            hasBRISQUE, hasNIQE);
        fprintf('%-12s %12.2f %12.4f %12.4f %12.4f\n', ...
            methodNames{k}, m, e, b, q);
    end

%% 9. Parameter experiments

    if RUN_PARAMETER_TESTS

% 測試不同 AGCWD alpha
        % ---- AGCWD alpha ----
        print_test_header('AGCWD alpha comparison', 'Alpha');
        for a = alphaList
            J = apply_enh(I, @(x) agcwd_method(x, a), isOver);
            print_test_row(a, J, hasBRISQUE, hasNIQE);
            imwrite(J, fullfile(outputFolder, ...
                sprintf('%s_AGCWD_alpha_%0.2f.bmp', baseName, a)));
        end

% 測試不同 SSR sigma
        % ---- SSR sigma ----
        print_test_header('SSR sigma comparison', 'Sigma');
        for s = sigmaList
            J = apply_enh(I, @(x) ssr_method(x, s, strength), isOver);
            print_test_row(s, J, hasBRISQUE, hasNIQE);
            imwrite(J, fullfile(outputFolder, ...
                sprintf('%s_SSR_sigma_%g.bmp', baseName, s)));
        end
% 測試不同 SSR strength
        print_test_header('SSR strength comparison', 'Strength');
        for st = strengthTestList
            J = apply_enh(I, @(x) ssr_method(x, sigma, st), isOver);
            print_test_row(st, J, hasBRISQUE, hasNIQE);
            imwrite(J, fullfile(outputFolder, ...
                sprintf('%s_SSR_strength_%0.2f.bmp', baseName, st)));
        end

% 測試不同 Tone Mapping k 
        % ---- Tone Mapping k ----
        print_test_header('Tone Mapping k comparison', 'k');
        for kk = toneTestList
            J = apply_enh(I, @(x) tone_mapping_method(x, kk), isOver);
            print_test_row(kk, J, hasBRISQUE, hasNIQE);
            imwrite(J, fullfile(outputFolder, ...
                sprintf('%s_ToneMapping_k_%g.bmp', baseName, kk)));
        end

% 測試不同 Gamma 值
        % ---- Gamma ----
        print_test_header('Gamma correction comparison', 'Gamma');
        for g = gammaTestList
            J = gamma_method(I, g);
            print_test_row(g, J, hasBRISQUE, hasNIQE);
            save_outputs(J, sprintf('Gamma_%0.2f', g), ...
                sprintf('Gamma Correction (gamma = %.2f)', g), ...
                baseName, outputFolder, orange);
        end
    end
end


fprintf('\n====================================\n');
fprintf('All processing completed.\n');
fprintf('Results saved in: %s\n', outputFolder);
fprintf('====================================\n');

diary off;


%% =========================================================
% Helper: apply a brightening method (invert for overexposed)
%% =========================================================

% I 為輸入影像，fcn 為增強函式，isOver 表示是否為過曝影像。
function J = apply_enh(I, fcn, isOver)

% 過曝圖先反相，讓原本偏亮的區域轉為偏暗，再執行增亮型方法。
    if isOver
        J = imcomplement(fcn(imcomplement(I)));
    else
        J = fcn(I);
    end
end


%% =========================================================
% Helper: evaluation metrics
%% =========================================================

% J 是待評估影像；hasB、hasN 表示對應指標函式是否存在。
function [m, e, b, q] = evaluate_image(J, hasB, hasN)

% 轉成灰階影像，讓平均灰階與熵使用相同的灰階資料計算。
    G = im2gray(J);
% 平均灰階：反映影像整體亮度，但不能單獨代表影像品質。
    m = mean(double(G(:)));
% 熵：衡量灰階分布的不確定性，可粗略反映影像資訊量。
    e = entropy(G);
% 預設為 NaN；若無法計算品質指標，就保留 NaN。
    b = NaN;
    q = NaN;

    if hasB

        try
            b = brisque(J);
        catch ME
            warning('BRISQUE failed: %s', ME.message);
        end
    end

    if hasN
        try
            q = niqe(J);
        catch ME
            warning('NIQE failed: %s', ME.message);
        end
    end
end


function print_test_header(titleText, paramName)

    fprintf('\n--- %s ---\n', titleText);
    fprintf('%-12s %12s %12s %12s %12s\n', ...
        paramName, 'Mean Gray', 'Entropy', 'BRISQUE', 'NIQE');
end


function print_test_row(paramValue, J, hasB, hasN)

    [m, e, b, q] = evaluate_image(J, hasB, hasN);
    fprintf('%-12g %12.2f %12.4f %12.4f %12.4f\n', paramValue, m, e, b, q);
end


%% =========================================================
% Method 1: Piecewise Linear Contrast Stretching
%% =========================================================

% 將像素轉為 0 到 1 的 double 浮點數，方便進行數值運算。
function J = piecewise_method(I)

    Id = im2double(I);

% 以第 2 與第 98 百分位作為拉伸上下界，降低極端像素的影響。
    low  = prctile(Id(:), 2);
    high = prctile(Id(:), 98);

    if high > low
% 將灰階線性映射到 0 到 1。
        Jd = (Id - low) / (high - low);
% 將超出範圍的值截斷到 0 到 1。
        Jd = min(max(Jd, 0), 1);
    else
        Jd = Id;
    end

% 將結果轉回 8 位元影像格式。
    J = im2uint8(Jd);
end


%% =========================================================
% Method 2: AGCWD
%% =========================================================

% 根據影像是灰階或彩色，選擇對應處理方式。
function J = agcwd_method(I, alpha)

% 判斷輸入是否為灰階影像。
    isGray = ismatrix(I) || size(I, 3) == 1;

% 灰階影像直接調整像素強度。
    if isGray
        V = im2double(I);
        J = im2uint8(agcwd_gray(V, alpha));
        return;
    end

% 彩色影像轉為 HSV，只調整 V（亮度）通道，以盡量保留色相與飽和度。
    HSV = rgb2hsv(I);
    HSV(:,:,3) = agcwd_gray(HSV(:,:,3), alpha);

    J = im2uint8(hsv2rgb(HSV));
end


% 依直方圖建立加權累積分布函數。
function V2 = agcwd_gray(V, alpha)

% 將亮度轉成 8 位元，統計 256 個灰階級別的像素數。
    G = im2uint8(V);
% 計算各灰階級別的機率。
    counts = imhist(G, 256);
    p = counts / sum(counts);

% 找出機率分布的最小值與最大值。
    pMin = min(p);
    pMax = max(p);

% 若機率沒有變化，代表分布無法有效加權，直接回傳原影像。
    if pMax <= pMin
        V2 = im2double(G);
        return;
    end

% 依 alpha 調整各灰階級別的權重；alpha 會影響權重曲線。
    pw = pMax .* ((p - pMin) ./ (pMax - pMin)) .^ alpha;

% 若權重總和為零，避免正規化時發生除以零。
    if sum(pw) <= 0
        V2 = im2double(G);
        return;
    end

% 將權重正規化成機率分布。
    pw = pw / sum(pw);
% 計算加權累積分布函數（CDF）。
    cdfw = cumsum(pw);

% 由加權 CDF 建立映射指數，並設下限避免指數過低。
    gammaMap = max(1 - cdfw, 0.01);
% 建立 256 階的查找表（LUT）。
    lut = zeros(256, 1, 'uint8');

% 逐一建立每個輸入灰階值對應的輸出值。
    for k = 0:255
% 將目前灰階值正規化至 0 到 1。
        x = k / 255;
% 使用冪次映射計算新的灰階值。
        y = x ^ gammaMap(k + 1);
        lut(k + 1) = uint8(round(255 * y));
    end

% 透過查找表快速轉換所有像素。
    G2 = intlut(G, lut);
    V2 = im2double(G2);
end


%% =========================================================
% Method 3: SSR
%% =========================================================

% sigma 控制照明估計尺度，strength 控制增強結果混合比例。
function J = ssr_method(I, sigma, strength)

% 判斷輸入影像是否為灰階。
    isGray = ismatrix(I) || size(I, 3) == 1;

% 灰階圖直接使用像素強度作為 V。
    if isGray
        V = im2double(I);
    else
% 彩色圖轉為 HSV，對 V 亮度通道進行增強，減少直接調整 RGB 造成的色偏。
        HSV = rgb2hsv(I);
        V = HSV(:,:,3);
    end

% 避免取對數時遇到零值。
    epsilon = 1e-2;

% 先以小尺度高斯濾波降低雜訊，避免 Retinex 過度放大細小雜訊。
    Vd = imgaussfilt(V, 1);
% 使用 sigma 對亮度進行高斯模糊，估計影像中的照明成分。
    illumination = imgaussfilt(Vd, sigma);

% Retinex：原亮度對數減去估計照明的對數，突出反射與細節資訊。
    R = log(Vd + epsilon) - log(illumination + epsilon);

% 使用百分位數設定結果的正規化範圍。
    low  = prctile(R(:), 2);
    high = prctile(R(:), 98);

% 將 Retinex 結果正規化到 0 到 1。
    if high > low
        R = (R - low) / (high - low);
        R = min(max(R, 0), 1);
    else
        R = V;
    end

% 將原始亮度與 Retinex 結果依 strength 混合。
    Vnew = (1 - strength) .* V + strength .* R;
    Vnew = min(max(Vnew, 0), 1);

% 再加強整體對比，1.25 大於 1 會拉開中間灰階附近的差異。
    contrastStrength = 1.25;
    Vnew = 0.5 + contrastStrength .* (Vnew - 0.5);
    Vnew = min(max(Vnew, 0), 1);

% 灰階影像直接輸出增強後的亮度。
    if isGray
        J = im2uint8(Vnew);
    else
% 保留原本的飽和度，並對較暗區域降低飽和度以減少色彩過濃。
        S = HSV(:,:,2);

% 建立暗部遮罩：越暗的像素，darkMask 越接近 1。
        darkMask = max(0, min(1, (0.35 - V) / 0.30));

% 暗部降低飽和度，降低增強後色彩過度鮮豔的情況。
        HSV(:,:,2) = S .* (1 - 0.55 .* darkMask);
        HSV(:,:,3) = Vnew;

% 將 HSV 轉回 RGB，並轉成 8 位元影像。
        J = im2uint8(hsv2rgb(HSV));
    end
end


%% =========================================================
% Method 4: Global Tone Mapping
%% =========================================================

% k 控制映射曲線；此處使用對數函數重新分配亮度。
function J = tone_mapping_method(I, k)

% 將影像轉成 0 到 1 的浮點數。
    Id = im2double(I);
    isGray = ismatrix(I) || size(I, 3) == 1;

% 灰階圖直接進行對數色調映射。
    if isGray
% 對數映射可重新分配亮度，壓縮部分高亮區域。
        Vnew = log(1 + k .* Id) ./ log(1 + k);
        J = im2uint8(min(max(Vnew, 0), 1));
    else
% 彩色圖轉為 HSV，只對 V 亮度通道進行映射。
        HSV = rgb2hsv(Id);
        V = HSV(:,:,3);

% 對亮度套用對數映射。
        Vnew = log(1 + k .* V) ./ log(1 + k);
        HSV(:,:,3) = min(max(Vnew, 0), 1);

        J = im2uint8(hsv2rgb(HSV));
    end
end


%% =========================================================
% Method 5: Histogram Equalization
%% =========================================================

% 將輸入影像依灰階或彩色分開處理。
function J = he_method(I)

    isGray = ismatrix(I) || size(I, 3) == 1;

% 灰階影像直接進行 256 階直方圖均衡化。
    if isGray
        J = histeq(I, 256);
    else
% 彩色影像轉 HSV，避免分別均衡化 RGB 三個通道而造成明顯色偏。
        HSV = rgb2hsv(im2double(I));
% 對 V 亮度通道進行直方圖均衡化。
        HSV(:,:,3) = histeq(HSV(:,:,3), 256);
        J = im2uint8(hsv2rgb(HSV));
    end
end


%% =========================================================
% Method 6: Gamma Correction
%% =========================================================

% gammaValue 是 Gamma 指數，控制暗部與亮部的映射方式。
function J = gamma_method(I, gammaValue)

% 將像素值轉成 0 到 1，方便進行冪次運算。
    Id = im2double(I);
    isGray = ismatrix(I) || size(I, 3) == 1;

% 灰階影像直接套用 Gamma 冪次函數。
    if isGray
% gamma < 1 通常會提亮影像；gamma > 1 通常會使影像變暗。
        Vnew = Id .^ gammaValue;
        J = im2uint8(min(max(Vnew, 0), 1));
    else
% 彩色影像轉 HSV，只調整 V 亮度通道。
        HSV = rgb2hsv(Id);
        V = HSV(:,:,3);

% 對亮度套用 Gamma 校正。
        Vnew = V .^ gammaValue;
        HSV(:,:,3) = min(max(Vnew, 0), 1);

        J = im2uint8(hsv2rgb(HSV));
    end
end


%% =========================================================
% Save one image (PNG) and its histogram (PNG) as separate files
%% =========================================================


function save_outputs(J, tag, histTitle, baseName, outputFolder, barColor)


    imwrite(J, fullfile(outputFolder, [baseName '_' tag '.png']));


    save_hist_figure(J, histTitle, ...
        fullfile(outputFolder, [baseName '_' tag '_Hist.png']), barColor);
end



function save_hist_figure(J, titleText, outputPath, barColor)


    G = im2gray(J);


    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 800 500]);


    ax = axes(fig);

    counts = histcounts(double(G(:)), -0.5:1:255.5);


    bar(ax, 0:255, counts, 1, ...
        'FaceColor', barColor, 'EdgeColor', 'none');


    xlim(ax, [0 255]);

    xlabel(ax, 'Gray Level');

    ylabel(ax, 'Pixel Count');

    title(ax, titleText, 'Interpreter', 'none');

    grid(ax, 'on');

    box(ax, 'on');


    exportgraphics(fig, outputPath, 'Resolution', 200);
    close(fig);
end
