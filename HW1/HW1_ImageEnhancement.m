clear; clc; close all;

%% 1. 參數與資料夾設定

inputFolder  = 'images';
outputFolder = 'results';
if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

logFile = fullfile(outputFolder, 'results_log.txt');
if exist(logFile, 'file'), delete(logFile); end
diary(logFile);

imageFiles = {'overexposed.jpg'; 'underexposed.jpg'};
isOverList = [true, false];

% 參數順序皆為：第一個對應過曝影像，第二個對應欠曝影像
% AGCWD 的 alpha 參數，控制加權灰階機率分布的形狀
agcwdAlphaList  = [0.7, 1.0];
% SSR 的高斯照明估計尺度 sigma
ssrSigmaList    = [90, 150];
% SSR 結果與原始亮度混合的比例，數值越大代表使用 SSR 結果的比例越高
ssrStrengthList = [0.45, 0.7];
% Gamma 校正參數：gamma 大於 1 通常使影像變暗，小於 1 通常使影像變亮
gammaList       = [2.5, 0.5];

methodNames = {'Original'; 'Piecewise'; 'AGCWD'; 'SSR'; 'HE'; 'BBHE'; 'Gamma'};

hasBRISQUE = exist('brisque', 'file') == 2;
hasNIQE = exist('niqe', 'file') == 2;
if ~(hasBRISQUE && hasNIQE)
    fprintf('Warning: BRISQUE / NIQE not found. Check your MATLAB toolboxes.\n');
end

%% 2. 逐張讀取並處理影像
for n = 1:numel(imageFiles)
    fileName = imageFiles{n};
    inputPath = fullfile(inputFolder, fileName)
    if ~exist(inputPath, 'file')
        warning('Image not found: %s', inputPath);
        continue;
    end

    % 讀取影像並轉成 8 位元格式，像素範圍為 0～255
    I = im2uint8(imread(inputPath));
    [~, baseName, ~] = fileparts(fileName);

    % 取出目前影像對應的類型與各方法參數
    isOver = isOverList(n);
    alpha = agcwdAlphaList(n);
    sigma = ssrSigmaList(n);
    strength = ssrStrengthList(n);
    gammaValue = gammaList(n);

    % 過曝影像的 AGCWD 會先反相處理再反相回來
    if isOver
        modeText = 'overexposed (AGCWD uses inversion; SSR does not)';
    else
        modeText = 'underexposed (no inversion)';
    end

    fprintf('\n====================================\n');
    fprintf('Image: %s -> %s\n', fileName, modeText);
    fprintf('AGCWD alpha = %.2f\n', alpha);
    fprintf('SSR sigma = %g, strength = %.2f\n', sigma, strength);
    fprintf('Gamma = %.2f\n', gammaValue);
    fprintf('====================================\n');

    %% 3. 執行六種影像增強方法
    % 分段線性對比拉伸：將指定百分位數範圍拉伸至完整灰階範圍
    J_piece = piecewise_method(I);
    % AGCWD：依據影像灰階分布建立自適應映射
    J_agcwd = apply_enh(I, @(x) agcwd_method(x, alpha), isOver);
    % SSR：估計照明分布並改善局部亮度；此方法不進行影像反相
    J_ssr = ssr_method(I, sigma, strength);
    % HE：直方圖均衡化，用以重新分配灰階值
    J_he = he_method(I);
    % BBHE：依平均灰階分成兩個子直方圖，再分別均衡化
    J_bbhe = bbhe_method(I);
    % Gamma 校正：透過冪次映射調整亮度
    J_gamma = gamma_method(I, gammaValue);

    %% 4. 儲存增強影像與灰階直方圖
    blue = [0.25 0.45 0.75];
    orange = [0.85 0.45 0.25];

    save_outputs(I, 'Original', 'Original Histogram', baseName, outputFolder, blue);
    save_outputs(J_gamma, 'Gamma', sprintf('Gamma Correction (gamma = %.2f)', gammaValue), ...
        baseName, outputFolder, orange);
    save_outputs(J_he, 'HE', 'Histogram Equalization (HE)', ...
        baseName, outputFolder, orange);
    save_outputs(J_bbhe, 'BBHE', 'Brightness Preserving Bi-Histogram Equalization (BBHE)', ...
        baseName, outputFolder, orange);
    save_outputs(J_piece, 'Piecewise', 'Piecewise Linear Contrast Stretching', ...
        baseName, outputFolder, orange);
    save_outputs(J_agcwd, 'AGCWD', sprintf('AGCWD (alpha = %.2f)', alpha), ...
        baseName, outputFolder, orange);
    save_outputs(J_ssr, 'SSR', sprintf('SSR (sigma = %g, strength = %.2f)', sigma, strength), ...
        baseName, outputFolder, orange);

    %% 5. 建立所有方法的影像比較圖
    figCompare = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1600 800]);
    tiledlayout(figCompare, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile; imshow(I);       title('Original');
    nexttile; imshow(J_piece); title('Piecewise');
    nexttile; imshow(J_agcwd); title(sprintf('AGCWD (alpha = %.2f)', alpha));
    nexttile; imshow(J_ssr);   title(sprintf('SSR (sigma = %g, strength = %.2f)', sigma, strength));
    nexttile; imshow(J_he);    title('HE');
    nexttile; imshow(J_bbhe);  title('BBHE');
    nexttile; imshow(J_gamma); title(sprintf('Gamma (%.2f)', gammaValue));

    exportgraphics(figCompare, fullfile(outputFolder, ...
        [baseName '_Overall_Comparison.png']), 'Resolution', 200);
    close(figCompare);

    %% 6. 計算影像品質指標並輸出結果
    imagesToEvaluate = {I, J_piece, J_agcwd, J_ssr, J_he, J_bbhe, J_gamma};

    fprintf('\n%-12s %12s %12s %12s %12s\n', ...
        'Method', 'Mean Gray', 'Entropy', 'BRISQUE', 'NIQE');
    fprintf('%s\n', repmat('-', 1, 64));

    for k = 1:numel(imagesToEvaluate)
        [m, e, b, q] = evaluate_image(imagesToEvaluate{k}, hasBRISQUE, hasNIQE);
        fprintf('%-12s %12.2f %12.4f %12.4f %12.4f\n', ...
            methodNames{k}, m, e, b, q);
    end
end

fprintf('\n====================================\nAll processing completed.\nResults saved in: %s\n====================================\n', outputFolder);
diary off;

%% 輔助函式：僅在處理過曝影像時，對 AGCWD 使用反相前後處理
% I：輸入影像；fcn：要執行的增強函式；isOver：是否為過曝影像
function J = apply_enh(I, fcn, isOver)
    if isOver
        J = imcomplement(fcn(imcomplement(I)));
    else
        J = fcn(I);
    end
end

%% 輔助函式：計算平均灰階、熵值、BRISQUE 與 NIQE
function [m, e, b, q] = evaluate_image(J, hasB, hasN)
    % 將輸出影像轉成灰階，以統計灰階直方圖
    G = im2gray(J);
    % 平均灰階
    m = mean(double(G(:)));
    % 熵值
    e = entropy(G);
    b = NaN; q = NaN;
    % BRISQUE
    if hasB
        try, b = brisque(J);
        catch ME, warning('BRISQUE failed: %s', ME.message);
        end
    end
    % NIQE
    if hasN
        try, q = niqe(J);
        catch ME, warning('NIQE failed: %s', ME.message);
        end
    end
end

%% 方法一：分段線性對比拉伸（Piecewise Linear Contrast Stretching）
function J = piecewise_method(I)
    % 轉成 double，將像素正規化至 0～1
    Id = im2double(I);
    % 取全影像第 2 百分位數作為拉伸下限，降低極暗像素的影響
    low = prctile(Id(:), 2);
    % 取第 98 百分位數作為拉伸上限，降低極亮像素的影響
    high = prctile(Id(:), 98);
    % 若上下限不同，才進行正規化，避免除以零
    if high > low
        % 將 low～high 線性映射至 0～1
        Jd = (Id - low) / (high - low);
        % 限制像素範圍，避免小於 0 或大於 1
        Jd = min(max(Jd, 0), 1);
    else
        Jd = Id;
    end
    J = im2uint8(Jd);
end

%% 方法二：自適應伽瑪校正與加權分布（AGCWD）
function J = agcwd_method(I, alpha)
    isGray = ismatrix(I) || size(I, 3) == 1;
    if isGray
        J = im2uint8(agcwd_gray(im2double(I), alpha));
        return;
    end
    % 彩色影像轉為 HSV，只調整 V（亮度）通道以減少色彩偏移
    HSV = rgb2hsv(I);
    HSV(:,:,3) = agcwd_gray(HSV(:,:,3), alpha);
    J = im2uint8(hsv2rgb(HSV));
end

function V2 = agcwd_gray(V, alpha)
    G = im2uint8(V);
    % 統計 256 個灰階級別的像素數量
    counts = imhist(G, 256);
    % 將像素數量正規化為灰階機率分布
    p = counts / sum(counts);
    pMin = min(p); pMax = max(p);
    if pMax <= pMin
        V2 = im2double(G);
        return;
    end
    % 依 alpha 重新加權灰階機率分布
    pw = pMax .* ((p - pMin) ./ (pMax - pMin)) .^ alpha;
    if sum(pw) <= 0
        V2 = im2double(G);
        return;
    end
    % 正規化加權後的機率分布
    pw = pw / sum(pw);
    % 計算加權累積分布函數（CDF）
    cdfw = cumsum(pw);
    % 由累積分布建立各灰階的 gamma 映射，並設定下限避免過小
    gammaMap = max(1 - cdfw, 0.01);
    % 建立 256 階查找表（LUT），加速灰階映射
    lut = zeros(256, 1, 'uint8');
    for k = 0:255
        x = k / 255;
        lut(k + 1) = uint8(round(255 * x ^ gammaMap(k + 1)));
    end
    V2 = im2double(intlut(G, lut));
end

%% 方法三：單尺度 Retinex
function J = ssr_method(I, sigma, strength)
    isGray = ismatrix(I) || size(I, 3) == 1;
    if isGray
        V = im2double(I);
    else
        HSV = rgb2hsv(I);
        V = HSV(:,:,3);
    end

    % 避免對數運算遇到 log(0) 而產生問題
    epsilon = 1e-2;
    % 先以小尺度高斯濾波平滑亮度通道
    Vd = imgaussfilt(V, 1);
    % 使用 sigma 控制的高斯模糊估計影像照明分布
    illumination = imgaussfilt(Vd, sigma);
    % Retinex 對數差：降低照明影響，凸顯反射與局部對比資訊
    R = log(Vd + epsilon) - log(illumination + epsilon);

    % 取 Retinex 結果的第 2 與第 98 百分位數進行正規化
    low = prctile(R(:), 2);
    high = prctile(R(:), 98);
    if high > low
        R = (R - low) / (high - low);
        R = min(max(R, 0), 1);
    else
        R = V;
    end

    % 將原始亮度與正規化後的 Retinex 結果依 strength 加權混合
    Vnew = (1 - strength) .* V + strength .* R;
    Vnew = min(max(Vnew, 0), 1);
    % 額外對比強度係數；大於 1 會增加對比
    contrastStrength = 1.25;
    Vnew = 0.5 + contrastStrength .* (Vnew - 0.5);
    Vnew = min(max(Vnew, 0), 1);

    if isGray
        J = im2uint8(Vnew);
    else
        S = HSV(:,:,2);
        % 建立暗部遮罩，讓較暗區域的飽和度降低一些
        darkMask = max(0, min(1, (0.35 - V) / 0.30));
        HSV(:,:,2) = S .* (1 - 0.55 .* darkMask);
        HSV(:,:,3) = Vnew;
        J = im2uint8(hsv2rgb(HSV));
    end
end

%% 方法四：直方圖均衡化（HE）
function J = he_method(I)
    isGray = ismatrix(I) || size(I, 3) == 1;
    if isGray
        % 灰階影像直接進行 256 階直方圖均衡化
        J = histeq(I, 256);
    else
        HSV = rgb2hsv(im2double(I));
        HSV(:,:,3) = histeq(HSV(:,:,3), 256);
        J = im2uint8(hsv2rgb(HSV));
    end
end

%% 方法五：保留亮度的雙直方圖均衡化（BBHE）
function J = bbhe_method(I)
    isGray = ismatrix(I) || size(I, 3) == 1;
    if isGray
        J = bbhe_gray(I);
    else
        % 對 HSV 的 V（亮度）通道套用 BBHE，以減少直接處理 RGB 造成的色偏
        HSV = rgb2hsv(im2double(I));
        V8 = im2uint8(HSV(:,:,3));
        HSV(:,:,3) = im2double(bbhe_gray(V8));
        J = im2uint8(hsv2rgb(HSV));
    end
end

function J = bbhe_gray(I)
    G = im2uint8(I);
    % 計算平均灰階，作為分割上下子直方圖的門檻依據
    meanGray = mean(double(G(:)));
    % 以平均灰階的整數部分作為分割門檻
    splitLevel = floor(meanGray);
    J = G;

    % 下半部：灰階小於或等於分割門檻的像素
    lowerMask = G <= splitLevel;
    % 上半部：灰階大於分割門檻的像素
    upperMask = G > splitLevel;

    % 將下半部子直方圖均衡化，並限制映射範圍在 0～splitLevel。
    if any(lowerMask(:))
        lowerPixels = G(lowerMask);
        lowMin = double(min(lowerPixels(:)));
        lowMax = double(max(lowerPixels(:)));
        if lowMax > lowMin
            cdf = subset_cdf(lowerPixels);
            cdfMin = cdf(lowMin + 1);
            denom = cdf(lowMax + 1) - cdfMin;
            if denom > 0
                vals = double(lowerPixels);
                mapped = round((cdf(vals + 1) - cdfMin) ./ denom .* splitLevel);
                mapped = min(max(mapped, 0), splitLevel);
                J(lowerMask) = uint8(mapped);
            end
        end
    end

    % 將上半部子直方圖均衡化，並限制映射範圍在 splitLevel+1～255。
    if any(upperMask(:))
        upperPixels = G(upperMask);
        upMin = double(min(upperPixels(:)));
        upMax = double(max(upperPixels(:)));
        if upMax > upMin
            cdf = subset_cdf(upperPixels);
            cdfMin = cdf(upMin + 1);
            denom = cdf(upMax + 1) - cdfMin;
            if denom > 0
                vals = double(upperPixels);
                mapped = splitLevel + 1 + round( ...
                    (cdf(vals + 1) - cdfMin) ./ denom .* (255 - splitLevel - 1));
                mapped = min(max(mapped, splitLevel + 1), 255);
                J(upperMask) = uint8(mapped);
            end
        end
    end
end

% 計算輸入像素的正規化累積直方圖（CDF）
function cdf = subset_cdf(pixels)
    counts = imhist(im2uint8(pixels), 256);
    cdf = cumsum(counts / max(sum(counts), 1));
end

%% 方法六：伽瑪校正（Gamma Correction）
function J = gamma_method(I, gammaValue)
    Id = im2double(I);
    isGray = ismatrix(I) || size(I, 3) == 1;
    if isGray
        % 套用冪次映射：Vnew = V^gamma
        Vnew = Id .^ gammaValue;
        J = im2uint8(min(max(Vnew, 0), 1));
    else
        % 彩色影像轉為 HSV，只調整 V（亮度）通道
        HSV = rgb2hsv(Id);
        HSV(:,:,3) = min(max(HSV(:,:,3) .^ gammaValue, 0), 1);
        J = im2uint8(hsv2rgb(HSV));
    end
end

%% 儲存增強影像與繪製直方圖
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
    bar(ax, 0:255, counts, 1, 'FaceColor', barColor, 'EdgeColor', 'none');
    xlim(ax, [0 255]);

    xlabel(ax, 'Gray Level');
    ylabel(ax, 'Pixel Count');
    title(ax, titleText, 'Interpreter', 'none');
    grid(ax, 'on');
    box(ax, 'on');
    exportgraphics(fig, outputPath, 'Resolution', 200);
    close(fig);
end
