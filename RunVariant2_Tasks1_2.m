% RunVariant2_Tasks1_2.m — Выполнение Задач 1 и 2 для Варианта 2 (Команда 2)
% QPSK, R_LDPC = 3/4, beta = 0.20, pilots = on, normal FECFRAME
clear; clc;

ParamsList = ReadSetup('Russian');
Params = SetParams(ParamsList{1}, 1, 'Russian');
Params = CalcAndCheckParams(Params, 'Russian');
[Objs, ~] = PrepareObjects(Params, 1, 1, 'Russian');
O = Objs{1};

fprintf('==============================================================\n');
fprintf('  ВАРИАНТ 2: QPSK, R_LDPC = 3/4, beta = 0.20, pilots = on\n');
fprintf('==============================================================\n');
fprintf('Параметры кадра:\n');
fprintf('  Kbch = %d бит, Nbch = %d бит, Nldpc = %d бит, tBCH = %d\n', ...
    Params.Encoder.Kbch, Params.Encoder.Nbch, Params.Encoder.Nldpc, Params.Encoder.tBCH);
fprintf('  Пакетов MPEG-TS в кадре: %d (DFL = %d бит, Padding = %d бит)\n', ...
    Params.Source.NumPackets, Params.Source.DFL, ...
    Params.Encoder.Kbch - 80 - Params.Source.DFL);
fprintf('  Символов XFECFRAME: %d (слотов: %d), пилотных блоков: %d (792 симв.)\n', ...
    32400, O.Sig.NumSlots, O.Sig.NumPilotBlocks);
fprintf('  Полная длина PLFRAME: %d символов, MODCOD = %d\n\n', ...
    O.Sig.PLFrameLength, Params.Sig.MODCOD);

%% ЗАДАЧА 1: Проверка полного восстановления MPEG-TS пакетов без шума
fprintf('--- ЗАДАЧА 1: Тест в отсутствие шума ---\n');
[TxBB, TxTS]   = O.Source.StepTx();
TxEnc          = O.Encoder.StepTx(TxBB);
TxInt          = O.Interleaver.StepTx(TxEnc);
TxSym          = O.Mapper.StepTx(TxInt);
TxSig          = O.Sig.StepTx(TxSym);

InstCh.Variance = 1e-10;
[RxSym, RxPLS] = O.Sig.StepRx(TxSig);
RxInt          = O.Mapper.StepRx(RxSym, InstCh);
RxEnc          = O.Interleaver.StepRx(RxInt);
RxBB           = O.Encoder.StepRx(RxEnc);
[RxTS, PktErr] = O.Source.StepRx(RxBB);

fprintf('  Декодированный PLHEADER -> MODCOD: %d (ожидался 7), FrameType: %d, Pilots: %d\n', ...
    RxPLS.MODCOD, RxPLS.FrameType, RxPLS.HasPilots);
fprintf('  Битовых ошибок в BBFRAME: %d из %d\n', sum(TxBB ~= RxBB), length(TxBB));
fprintf('  Битовых ошибок в MPEG-TS: %d из %d\n', sum(TxTS ~= RxTS), length(TxTS));
fprintf('  Ошибочных пакетов по CRC-8: %d из %d (PER = %.2f)\n\n', ...
    sum(PktErr), length(PktErr), mean(PktErr));

%% ЗАДАЧА 2: Сравнение с функцией dvbs2BitRecover при фиксированном Es/N0
fprintf('--- ЗАДАЧА 2: Сравнение с dvbs2BitRecover при Es/N0 = 3.90 дБ ---\n');
EsN0dB = 3.90;
N0 = 10^(-EsN0dB / 10);
InstCh.Variance = N0;

if exist('dvbs2WaveformGenerator', 'file') && exist('dvbs2BitRecover', 'file')
    cfg = dvbs2WaveformGenerator('FECFrame', 'normal', ...
        'MODCOD', 7, ...
        'DFL', Params.Source.DFL, ...
        'HasPilots', true, ...
        'RolloffFactor', 0.20, ...
        'SamplesPerSymbol', Params.Sig.SamplesPerSymbol, ...
        'FilterSpanInSymbols', Params.Sig.FilterSpanInSymbols);

    syncByte = de2bi(hex2dec('47'), 8, 'left-msb').';
    rawPkts  = zeros(1504, Params.Source.NumPackets);
    for p = 1:Params.Source.NumPackets
        rawPkts(:, p) = [syncByte; randi([0 1], 1496, 1)];
    end
    txWave = cfg(rawPkts(:));

    % Добавление комплексного АБГШ к отсчётам сигнала
    noise = sqrt(N0 / 2) * (randn(size(txWave)) + 1i*randn(size(txWave)));
    rxWave = txWave + noise;

    % Приём эталонной функцией MATLAB dvbs2BitRecover
    [refBitsCell, ~, refCRCCell] = dvbs2BitRecover(rxWave, N0, ...
        'RolloffFactor', 0.20, ...
        'SamplesPerSymbol', Params.Sig.SamplesPerSymbol);
    refBits = double(refBitsCell{1});
    refErrFlags = double(~refCRCCell{1});

    % Приём реализованной моделью из того же входного сигнала rxWave
    padZeros = zeros(Params.Sig.FilterSpanInSymbols * Params.Sig.SamplesPerSymbol, 1);
    [myRxSym, myPLS]  = O.Sig.StepRx([rxWave; padZeros]);
    myRxInt           = O.Mapper.StepRx(myRxSym, InstCh);
    myRxEnc           = O.Interleaver.StepRx(myRxInt);
    myRxBB            = O.Encoder.StepRx(myRxEnc);
    [myBits, myErrFlags] = O.Source.StepRx(myRxBB);
    fprintf('  Несовпадающих бит между моделью и dvbs2BitRecover: %d из %d\n', ...
        sum(refBits ~= myBits), length(myBits));
    fprintf('  Ошибочных пакетов по CRC-8 (модель / dvbs2BitRecover): %d / %d из %d\n', ...
        sum(myErrFlags), sum(refErrFlags), length(myErrFlags));
    fprintf('  Полное совпадение результатов CRC-8: %d%%\n', ...
        100 * all(myErrFlags == refErrFlags));
else
    fprintf('  Satellite Communications Toolbox не установлен; выполнен тест собственного тракта при Es/N0 = %.2f дБ:\n', EsN0dB);
    [RxSigNoisy, InstCh] = O.Channel.Step(TxSig, EsN0dB);
    [RxSymN, RxPLSN] = O.Sig.StepRx(RxSigNoisy);
    RxIntN           = O.Mapper.StepRx(RxSymN, InstCh);
    RxEncN           = O.Interleaver.StepRx(RxIntN);
    RxBBN            = O.Encoder.StepRx(RxEncN);
    [RxTSN, PktErrN] = O.Source.StepRx(RxBBN);
    fprintf('  Декодирован MODCOD = %d, ошибочных бит: %d, ошибочных пакетов по CRC-8: %d из 32\n', ...
        RxPLSN.MODCOD, sum(TxTS ~= RxTSN), sum(PktErrN));
end