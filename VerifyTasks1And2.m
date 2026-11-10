% VerifyTasks1And2.m — Проверка Задач 1 и 2 лабораторной работы DVB-S2 Receiver
clear; clc;

% Укажите номер вашей команды (от 1 до 8):
TeamNumber = 1;

ParamsList = ReadSetup('Russian');
Params = SetParams(ParamsList{TeamNumber}, TeamNumber, 'Russian');
Params = CalcAndCheckParams(Params, 'Russian');
[Objs, ~] = PrepareObjects(Params, TeamNumber, length(ParamsList), 'Russian');
O = Objs{1};

fprintf('=== ЗАДАЧА 1: Проверка тракта для Команды %d без шума ===\n', TeamNumber);
[TxBB, TxTS] = O.Source.StepTx();
TxEnc        = O.Encoder.StepTx(TxBB);
TxInt        = O.Interleaver.StepTx(TxEnc);
TxSym        = O.Mapper.StepTx(TxInt);
TxSig        = O.Sig.StepTx(TxSym);

% Прохождение без шума
InstCh.Variance = 1e-10;
[RxSym, RxPLS]  = O.Sig.StepRx(TxSig);
RxInt           = O.Mapper.StepRx(RxSym, InstCh);
RxEnc           = O.Interleaver.StepRx(RxInt);
RxBB            = O.Encoder.StepRx(RxEnc);
[RxTS, PktErr]  = O.Source.StepRx(RxBB);

fprintf('Декодированный MODCOD: %d (ожидался %d), Пилоты: %d\n', ...
    RxPLS.MODCOD, Params.Sig.MODCOD, RxPLS.HasPilots);
fprintf('Ошибочных бит MPEG-TS: %d из %d\n', sum(TxTS ~= RxTS), length(TxTS));
fprintf('Ошибочных пакетов (CRC-8): %d из %d\n\n', sum(PktErr), length(PktErr));

% === ЗАДАЧА 2: Сравнение с функцией dvbs2BitRecover при фиксированном Es/N0 ===
if exist('dvbs2WaveformGenerator', 'file') && exist('dvbs2BitRecover', 'file')
    fprintf('=== ЗАДАЧА 2: Сравнение с dvbs2BitRecover ===\n');
    cfg = dvbs2WaveformGenerator('FECFrame', 'normal', ...
        'MODCOD', Params.Sig.MODCOD, ...
        'DFL', Params.Source.DFL, ...
        'HasPilots', Params.Sig.HasPilots, ...
        'RolloffFactor', Params.Sig.RollOff, ...
        'SamplesPerSymbol', Params.Sig.SamplesPerSymbol, ...
        'FilterSpanInSymbols', Params.Sig.FilterSpanInSymbols);

    % Генерация входных пакетов MPEG-TS (с синхробайтом 0x47)
    syncByte = de2bi(hex2dec('47'), 8, 'left-msb').';
    rawPkts  = zeros(1504, Params.Source.NumPackets);
    for p = 1:Params.Source.NumPackets
        rawPkts(:, p) = [syncByte; randi([0 1], 1496, 1)];
    end
    txWaveform = cfg(rawPkts(:));

    % Добавление АБГШ при фиксированном Es/N0
    EsN0dB = Params.BER.h2dBInit + 0.2;
    N0 = 10^(-EsN0dB / 10);
    noise = sqrt(N0 / 2 / Params.Sig.SamplesPerSymbol) * ...
        (randn(size(txWaveform)) + 1i*randn(size(txWaveform)));
    rxWaveform = txWaveform + noise;

    % 1. Восстановление стандартной функцией dvbs2BitRecover
    [refBits, isFrameLost, refPktCRC] = dvbs2BitRecover(rxWaveform, N0, ...
        'RolloffFactor', Params.Sig.RollOff, ...
        'SamplesPerSymbol', Params.Sig.SamplesPerSymbol);

    % 2. Восстановление нашим приёмником из того же сигнала
    InstCh.Variance = N0;
    [myRxSym, ~]   = O.Sig.StepRx([rxWaveform; zeros(Params.Sig.FilterSpanInSymbols * Params.Sig.SamplesPerSymbol, 1)]);
    myRxInt        = O.Mapper.StepRx(myRxSym, InstCh);
    myRxEnc        = O.Interleaver.StepRx(myRxInt);
    myRxBB         = O.Encoder.StepRx(myRxEnc);
    [myBits, myPktErr] = O.Source.StepRx(myRxBB);

    fprintf('Несовпадающих бит между нашим приёмником и dvbs2BitRecover: %d\n', ...
        sum(double(refBits{1}) ~= myBits));
    fprintf('Совпадение статусов CRC-8 пакетов: %d%%\n', ...
        100 * mean(double(~refPktCRC{1}) == myPktErr));
end