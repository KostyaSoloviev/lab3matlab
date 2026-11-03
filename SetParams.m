function Params = SetParams(inParams, ParamsNumber, LogLanguage)
    Params = inParams;
    FieldNames = { ...
        'Source', ...
        'Encoder', ...
        'Interleaver', ...
        'Mapper', ...
        'Sig', ...
        'Channel', ...
        'BER', ...
        'Common' ...
    };
    for n = 1:length(FieldNames)
        if ~isfield(Params, FieldNames{n})
            Params.(FieldNames{n}) = [];
        end
        Fun = str2func(['SetParams', FieldNames{n}]);
        Params.(FieldNames{n}) = Fun(Params.(FieldNames{n}), ...
            ParamsNumber, LogLanguage);
    end
end

function Source = SetParamsSource(inSource, ~, ~)
    Source = inSource;
    if ~isfield(Source, 'RollOff')
        Source.RollOff = 0.35; % 0.35 | 0.25 | 0.20
    end
end

function Encoder = SetParamsEncoder(inEncoder, ~, ~)
    Encoder = inEncoder;
    if ~isfield(Encoder, 'isTransparent')
        Encoder.isTransparent = false;
    end
    if ~isfield(Encoder, 'CodeRate')
        Encoder.CodeRate = '1/2'; % '1/2' | '3/5' | '2/3' | '3/4' | '5/6' и др.
    end
    if ~isfield(Encoder, 'NumIterations')
        Encoder.NumIterations = 50;
    end
end

function Interleaver = SetParamsInterleaver(inInterleaver, ~, ~)
    Interleaver = inInterleaver;
    if ~isfield(Interleaver, 'isTransparent')
        Interleaver.isTransparent = false;
    end
end

function Mapper = SetParamsMapper(inMapper, ~, ~)
    Mapper = inMapper;
    if ~isfield(Mapper, 'isTransparent')
        Mapper.isTransparent = false;
    end
    if ~isfield(Mapper, 'Type')
        Mapper.Type = 'QPSK'; % 'QPSK' | '8PSK' | '16APSK' | '32APSK'
    end
    if ~isfield(Mapper, 'ModulationOrder')
        Mapper.ModulationOrder = 4;
    end
    if ~isfield(Mapper, 'DecisionMethod')
        Mapper.DecisionMethod = 'Approximate log-likelihood ratio';
    end
end

function Sig = SetParamsSig(inSig, ~, ~)
    Sig = inSig;
    if ~isfield(Sig, 'isTransparent')
        Sig.isTransparent = false;
    end
    if ~isfield(Sig, 'HasPilots')
        Sig.HasPilots = true;
    end
    if ~isfield(Sig, 'RollOff')
        Sig.RollOff = 0.35;
    end
    if ~isfield(Sig, 'FilterSpanInSymbols')
        Sig.FilterSpanInSymbols = 10;
    end
    if ~isfield(Sig, 'SamplesPerSymbol')
        Sig.SamplesPerSymbol = 4;
    end
    if ~isfield(Sig, 'ScramblerIndex')
        Sig.ScramblerIndex = 0;
    end
end

function Channel = SetParamsChannel(inChannel, ~, ~)
    Channel = inChannel;
    if ~isfield(Channel, 'isTransparent')
        Channel.isTransparent = false;
    end
    if ~isfield(Channel, 'Type')
        Channel.Type = 'AWGN';
    end
end

function BER = SetParamsBER(inBER, ~, ~)
    BER = inBER;
    if ~isfield(BER, 'h2Precision'),      BER.h2Precision = 2; end
    if ~isfield(BER, 'BERPrecision'),     BER.BERPrecision = 8; end
    if ~isfield(BER, 'BERNumRateDigits'), BER.BERNumRateDigits = 10; end
    if ~isfield(BER, 'FERNumRateDigits'), BER.FERNumRateDigits = 7; end
    if ~isfield(BER, 'MinNumTrFrames'),   BER.MinNumTrFrames = 20; end
    if ~isfield(BER, 'h2dBInit'),         BER.h2dBInit = 0.5; end
    if ~isfield(BER, 'h2dBInitStep'),     BER.h2dBInitStep = 0.1; end
    if ~isfield(BER, 'h2dBMaxStep'),      BER.h2dBMaxStep = 0.4; end
    if ~isfield(BER, 'h2dBMinStep'),      BER.h2dBMinStep = 0.05; end
    if ~isfield(BER, 'h2dBMax'),          BER.h2dBMax = 16; end
    if ~isfield(BER, 'MinBER'),           BER.MinBER = 1e-6; end
    if ~isfield(BER, 'MinNumErBits'),     BER.MinNumErBits = 100; end
    if ~isfield(BER, 'MinFER'),           BER.MinFER = 1e-4; end
    if ~isfield(BER, 'MinNumErFrames'),   BER.MinNumErFrames = 30; end
    if ~isfield(BER, 'MaxNumTrBits'),     BER.MaxNumTrBits = 5e7; end
    if ~isfield(BER, 'MaxNumTrFrames'),   BER.MaxNumTrFrames = 5000; end
    if ~isfield(BER, 'MaxBERRate'),       BER.MaxBERRate = 5; end
    if ~isfield(BER, 'MinBERRate'),       BER.MinBERRate = 2; end
end

function Common = SetParamsCommon(inCommon, ParamsNumber, ~)
    Common = inCommon;
    if ~isfield(Common, 'SaveFileName')
        Common.SaveFileName = sprintf('Results%02d', ParamsNumber);
    end
    if ~isfield(Common, 'SaveDirName'),        Common.SaveDirName = 'Results'; end
    if ~isfield(Common, 'NumOneIterFrames'),   Common.NumOneIterFrames = 10; end
    if ~isfield(Common, 'NumWorkers'),         Common.NumWorkers = 1; end
    if ~isfield(Common, 'isRealTimeLogCWin'),  Common.isRealTimeLogCWin = 1; end
    if ~isfield(Common, 'isRealTimeLogFile'),  Common.isRealTimeLogFile = 0; end
end