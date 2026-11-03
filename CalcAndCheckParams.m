function Params = CalcAndCheckParams(inParams, ~)
    Params = inParams;

    % Синхронизируем RollOff между Source и Sig
    Params.Source.RollOff = Params.Sig.RollOff;

    % Таблица параметров для normal FECFRAME (n_ldpc = 64800)
    Params.Encoder.Nldpc = 64800;
    switch Params.Encoder.CodeRate
        case '1/4', Kbch = 16008; Nbch = 16200; t = 12; RateVal = 1/4;
        case '1/3', Kbch = 21408; Nbch = 21600; t = 12; RateVal = 1/3;
        case '2/5', Kbch = 25728; Nbch = 25920; t = 12; RateVal = 2/5;
        case '1/2', Kbch = 32208; Nbch = 32400; t = 12; RateVal = 1/2;
        case '3/5', Kbch = 38688; Nbch = 38880; t = 12; RateVal = 3/5;
        case '2/3', Kbch = 43040; Nbch = 43200; t = 10; RateVal = 2/3;
        case '3/4', Kbch = 48408; Nbch = 48600; t = 12; RateVal = 3/4;
        case '4/5', Kbch = 51648; Nbch = 51840; t = 12; RateVal = 4/5;
        case '5/6', Kbch = 53840; Nbch = 54000; t = 10; RateVal = 5/6;
        case '8/9', Kbch = 57472; Nbch = 57600; t = 8;  RateVal = 8/9;
        case '9/10',Kbch = 58192; Nbch = 58320; t = 8;  RateVal = 9/10;
        otherwise, error('Неподдерживаемая скорость кода LDPC');
    end
    Params.Encoder.Kbch = Kbch;
    Params.Encoder.Nbch = Nbch;
    Params.Encoder.tBCH = t;
    Params.Encoder.RateVal = RateVal;

    % Выбираем DFL кратным 1504 битам (целое число пакетов MPEG-TS)
    UPL = 1504;
    NumPackets = floor((Kbch - 80) / UPL);
    Params.Source.UPL = UPL;
    Params.Source.NumPackets = NumPackets;
    Params.Source.DFL = NumPackets * UPL;
    Params.Source.Kbch = Kbch;
    Params.Source.NumBitsPerFrame = NumPackets * UPL;

    % Определение порядка модуляции и MODCOD (Table 12 DVB-S2)
    switch Params.Mapper.Type
        case 'QPSK'
            Params.Mapper.ModulationOrder = 4;
            Params.Interleaver.isTransparent = true; % Для QPSK перемежение не используется
            rates = {'1/4','1/3','2/5','1/2','3/5','2/3','3/4','4/5','5/6','8/9','9/10'};
            vals  = 1:11;
        case '8PSK'
            Params.Mapper.ModulationOrder = 8;
            rates = {'3/5','2/3','3/4','5/6','8/9','9/10'};
            vals  = 12:17;
        case '16APSK'
            Params.Mapper.ModulationOrder = 16;
            rates = {'2/3','3/4','4/5','5/6','8/9','9/10'};
            vals  = 18:23;
        case '32APSK'
            Params.Mapper.ModulationOrder = 32;
            rates = {'3/4','4/5','5/6','8/9','9/10'};
            vals  = 24:28;
        otherwise
            error('Неизвестный тип модуляции DVB-S2');
    end
    idx = find(strcmp(Params.Encoder.CodeRate, rates), 1);
    if isempty(idx)
        error('Недопустимая комбинация модуляции и скорости кода');
    end
    Params.Sig.MODCOD = vals(idx);
    Params.Sig.ModulationOrder = Params.Mapper.ModulationOrder;
    Params.Mapper.CodeRate = Params.Encoder.CodeRate;
    Params.Interleaver.ModulationOrder = Params.Mapper.ModulationOrder;
    Params.Interleaver.CodeRate = Params.Encoder.CodeRate;
end