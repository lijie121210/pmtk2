classdef MvnDist < MultivarDist
% Multivariate Normal Distribution


	properties
		dof;
		ndimensions;
		params;
		prior;
        infEng;
        fitEng;
    end
    
    properties
        covType;
    end
    
   

	methods

		function model = MvnDist(varargin)
           
            [ model.params.mu , model.params.Sigma        ,...
              model.prior     , model.ndimensions         ,...
              model.infEng    , model.fitEng              ,...
              model.covType   , model.params.domain       ,...
            ] = processArgs(varargin                      ,...
              '-mu'          , []                         ,...
              '-Sigma'       , []                         ,...
              '-prior'       , NoPrior()                  ,...
              '-ndimensions' , []                         ,...
              '-infEng'      , MvnJointGaussInfEng()      ,...
              '-fitEng'      , []                         ,...
              '-covType'     , 'full'                     ,...
              '-domain'      , []                         );
            model = initialize(model); % sets ndimensions, dof
        end

        
        function M = infer(model,varargin)   
            [Q,D,expand] = processArgs(varargin,'+-query',Query(),'+-data',DataTable(),'-expand',false); 
            nc = ncases(D);
            if nc < 2
                M = computeMarginals(enterEvidence(model.infEng,model,D),Q);
            elseif ~expand
                M = cell(nc,1);
                for i=1:nc
                    M{i} = rowvec(computeMarginals(enterEvidence(model.infEng,model,D(i)),Q));
                end
            else 
                M = cell(nc,model.ndimensions);
                for i=1:nc
                    eng = enterEvidence(model.infEng,model,D(i));
                    [marg,v] = computeMarginals(eng,Q);
                    M(i,unwrapCell(v)) = marg;
                end
            end
             M = unwrapCell(M); 
        end
        
        function varargout = computeFunPost(model,varargin)
        % Compute a function of the posterior    
            [Q,D,funstr] = processArgs(varargin,'+-query',Query(),'+-data',DataTable(),'-func','mode');
            if iscell(funstr)
               varargout = cellfuncell(@(f)computeFunPost(model,Q,D,f),funstr) ; return;
            end
            func = str2func(funstr);
            P = infer(model,Q,D,'-expand',~isRagged(Q)); % if ~ragged, expand P to ncases(D)-by-model.ndimensions with possibly empty cells
            if ~iscell(P)
                 varargout = {func(P)};
            else
                M = unwrapCell(cellfuncell(protect(func,NaN),P));
                if isnumeric(M) 
                    switch funstr
                        case {'mean','mode'}  % fill in blanks with the data
                            X = D.X;
                            ndx = isnan(M);
                            M(isnan(M)) = X(ndx);
                        otherwise
                            M(isnan(M)) = 0;
                    end
                end
                varargout = {M};
            end
        end
        
        
        
        
        
%         function mat = computeFunPostMissing(model,D)
%             
%         end
%         
        
%         function M = computeMap(model,varargin)    
%             [Q,D] = processArgs(varargin,'+-query',Query(),'+-data',DataTable());
%             M = rowvec(mode(infer(model,Q,D(1))));
%             nc = ncases(D);
%             if nc > 1
%                M = [M,zeros(nc-1,size(M,2))];
%                for i=2:nc
%                    M(i,:) = rowvec(mode(infer(model,Q,D(i))));
%                end
%             end
%         end
        
%         function D = computeMapMissing(model,D)
%         % imputation
%             for i=1:ncases(D)
%                 hid = hidden(D(i));
%                 D(i,hid) = mode(infer(model,Query(hid),D(i,visible(D(i)))));    
%             end   
%         end
        
        function S = cov(model,varargin)
            S = model.params.Sigma;
		end

		function H = entropy(model)
           H = 0.5*logdet(model.params.Sigma) + (model.ndimensions/2)*(1+log(2*pi));
        end
        
        function SS = mkSuffStat(model,D,weights) %#ok
        % SS.n
        % SS.xbar = 1/n sum_i X(i,:)'
        % SS.XX(j,k) = 1/n sum_i XC(i,j) XC(i,k) - centered around xbar
        % SS.XX2(j,k) = 1/n sum_i X(i,j) X(i,k)  - not mean centered
            if nargin < 3, weights = ones(ncases(D),1); end
            X = D.X;
            SS.n = sum(weights,1);
            SS.xbar = rowvec(sum(bsxfun(@times,X,weights))'/SS.n);  % bishop eq 13.20
            SS.XX2 = bsxfun(@times,X,weights)'*X/SS.n;
            X = bsxfun(@minus,X,SS.xbar);
            SS.XX = bsxfun(@times,X,weights)'*X/SS.n;
        end

		function [model,success,diagn] = fit(model,varargin)
            if isempty(model.fitEng)
                [D,SS] = processArgs(varargin,'+-data',DataTable(),'-suffStat',[]);
                
                switch class(model.prior)
                    case 'NoPrior'
                        if isempty(SS)
                            X = D.X;
                            mu = mean(X,1);
                            Sigma = cov(X);
                        else
                            mu    = SS.xbar;
                            Sigma = SS.XX;
                        end
                    otherwise
                        [mu,Sigma] = fitMap(model,varargin);
                end
                success = isposdef(model.params.Sigma);
                model.params.mu    = mu;
                model.params.Sigma = Sigma;
                diagn = [];
            else
               [model,success,diagn] = fit(model.fitEng,model,varargin{:}); 
            end
            model = initialize(model);  % sets dof, ndimensions, etc
		end

		function logp = logPdf(model,D)
            logp = computeLogPdf(model.infEng,model,D);
		end

		function mu = mean(model)
            mu = model.params.mu;
		end

		function mu = mode(model,varargin)
            mu = mean(model,varargin{:});
		end

		function h = plotPdf(model,varargin)
            if model.ndimensions == 2
                h = gaussPlot2d(model.params.mu,model.params.Sigma);
            else
               notYetImplemented('Only 2D plotting currently supported'); 
            end
		end

		function S = sample(model,n)
            if nargin < 2, n = 1; end
            S = computeSamples(model.infEng,model,n);
        end
        
		function v = var(model,varargin)
            v = diag(model.params.Sigma);
        end
    end
    
    
    
    
    
    
    methods(Access = 'protected')
       
        function model = initialize(model)
        % Called from constructor and fit    
            model.params.mu = rowvec(model.params.mu);
            d = length(model.params.mu);
            if isempty(model.ndimensions)
                model.ndimensions = d;
            end
            model.dof = d + ((d*(d+1))/2);   % Not d^2 since Sigma is symmetric 
            if isempty(model.params.domain)
               model.params.domain = 1:length(model.params.mu); 
            end
        end
        
        
        function [mu,Sigma] = fitMap(model,SS)
            notYetImplemented('MVN Map Estimation');
        end
        
        
    end


end

