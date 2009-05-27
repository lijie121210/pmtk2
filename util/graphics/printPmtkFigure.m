function printPmtkFigure(filename)
% print current figure to specified file in .eps and .pdf formats

if true % set to false to turn off printing
  printFolder = '/ubc/cs/home/n/nevek/fig';
  %printFolder = 'C:\kmurphy\pmtkLocal\figures/';
  pdfcrop;
  opts = struct('Color', 'rgb', 'Resolution', 1200);
  try
    exportfig(gcf, sprintf('%s/%s.eps', printFolder, filename), opts, 'Format', 'eps' );
    exportfig(gcf, sprintf('%s/%s.pdf', printFolder, filename), opts, 'Format', 'pdf' );
    %export_fig(fullfile(printFolder, sprintf('%s.pdf', filename)), '-pdf');
    %export_fig(fullfile(printFolder, sprintf('%s.eps', filename)), '-eps');
  catch ME
    fprintf('could not print to %s/%s; edit printPmtkFigure.m\n', printFolder, filename);
  end
end
