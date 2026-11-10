classdef ClassEncoder < handle
    properties (SetAccess = private)
        isTransparent;
        Kbch;
        Nbch;
        Nldpc;
        tBCH;
        RateVal;
        NumIterations;
        LogLanguage;
        BCHEnc;
        BCHDec;
        LDPCEncCfg;
        LDPCDecCfg;
    end
    methods
        function obj = ClassEncoder(Params, LogLanguage)
            E = Params.Encoder;
            obj.isTransparent = E.isTransparent;
            obj.Kbch          = E.Kbch;
            obj.Nbch          = E.Nbch;
            obj.Nldpc         = E.Nldpc;
            obj.tBCH          = E.tBCH;
            obj.RateVal       = E.RateVal;
            obj.NumIterations = E.NumIterations;
            obj.LogLanguage   = LogLanguage;

            if ~obj.isTransparent
                % Порождающий полином BCH (вектор-строка double) и примитивный полином GF(2^16) = g1(x)
                [gPoly, primPoly] = obj.getBCHPolynomial(obj.tBCH);
                obj.BCHEnc = comm.BCHEncoder( ...
                    'CodewordLength', obj.Nbch, ...
                    'MessageLength', obj.Kbch, ...
                    'PrimitivePolynomialSource', 'Property', ...
                    'PrimitivePolynomial', primPoly, ...
                    'GeneratorPolynomialSource', 'Property', ...
                    'GeneratorPolynomial', gPoly);
                obj.BCHDec = comm.BCHDecoder( ...
                    'CodewordLength', obj.Nbch, ...
                    'MessageLength', obj.Kbch, ...
                    'PrimitivePolynomialSource', 'Property', ...
                    'PrimitivePolynomial', primPoly, ...
                    'GeneratorPolynomialSource', 'Property', ...
                    'GeneratorPolynomial', gPoly);

                % Проверочная матрица LDPC стандарта DVB-S2
                H = dvbs2ldpc(obj.RateVal);
                obj.LDPCEncCfg = ldpcEncoderConfig(H);
                obj.LDPCDecCfg = ldpcDecoderConfig(H);
            end
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            bchCodeword = obj.BCHEnc(double(InData(:)));
            OutData = double(ldpcEncode(bchCodeword, obj.LDPCEncCfg));
        end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = double(InData < 0);
                return;
            end
            % Итеративное декодирование LDPC (выход - первые Nbch информационных бит)
            ldpcDecBits = ldpcDecode(InData(:), obj.LDPCDecCfg, obj.NumIterations, ...
                'OutputFormat', 'info', 'DecisionType', 'hard');
            % Декодирование внешнего кода БЧХ
            bchDecBits = obj.BCHDec(double(ldpcDecBits(:)));
            OutData = double(bchDecBits);
        end
    end

    methods (Static)
        function [g, primPoly] = getBCHPolynomial(t)
            % Таблица 6a полиномов БЧХ для normal FECFRAME (n_ldpc = 64800) в порядке по убыванию степеней x^16 ... x^0
            p = cell(12, 1);
            p{1}  = [1 0 0 0 0 0 0 0 0 0 0 1 0 1 1 0 1];
            p{2}  = [1 0 0 0 0 0 0 0 1 0 1 1 1 0 0 1 1];
            p{3}  = [1 0 0 0 0 1 1 1 1 1 0 1 1 1 1 0 1];
            p{4}  = [1 0 0 0 1 1 1 1 1 0 0 1 0 1 1 1 1];
            p{5}  = [1 1 1 1 1 0 1 1 1 1 0 1 1 0 1 0 1];
            p{6}  = [1 1 0 1 0 1 1 1 1 0 1 1 0 0 1 0 1];
            p{7}  = [1 0 1 0 1 1 0 1 0 0 1 0 1 0 1 0 1];
            p{8}  = [1 0 1 1 1 0 0 1 1 0 1 1 0 0 1 1 1];
            p{9}  = [1 0 0 0 0 1 1 1 0 1 0 1 0 0 0 0 1];
            p{10} = [1 0 1 1 1 0 1 0 1 1 0 1 0 0 1 1 1];
            p{11} = [1 0 0 1 1 1 0 1 0 0 0 1 0 1 1 0 1];
            p{12} = [1 0 0 0 1 1 0 1 0 1 1 1 0 0 0 1 1];

            primPoly = double(p{1}); % Примитивный полином GF(2^16): 1 + x^2 + x^3 + x^5 + x^16
            g = p{1};
            for k = 2:t
                g = mod(conv(g, p{k}), 2);
            end
            g = double(g(:).'); % Строго вектор-строка типа double
        end
    end
end