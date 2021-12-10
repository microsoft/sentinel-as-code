using Kusto.Language;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Management.Automation;

namespace Azure.Kql.Powershell
{
    [Cmdlet("Invoke", "KqlValidator")]
    public class KqlValidatorCommand : Cmdlet
    {
        #region · Public ·
        public KqlValidatorCommand()
        {

        }

        [Parameter(Mandatory = true)]
        [ValidateNotNullOrEmpty]
        public string KQLExpression
        {
            get;
            set;
        }

        #endregion
        #region · Protected ·

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            if (!string.IsNullOrEmpty(KQLExpression) && !string.IsNullOrWhiteSpace(KQLExpression))
            {
                KustoCode kustoCode = KustoCode.Parse(KQLExpression);
                IReadOnlyCollection<Diagnostic> diagnostics = kustoCode.GetDiagnostics();
                foreach (Diagnostic diagnostic in diagnostics)
                {
                    string severity = diagnostic.Severity;
                    switch (severity)
                    {
                        case "Error":
                            ErrorRecord errorRecord = new ErrorRecord(new KqlValidationException(diagnostic), diagnostic.Code, ErrorCategory.ParserError, severity);
                            this.WriteError(errorRecord);
                            break;
                        case "Warning":
                            this.WriteWarning($"{diagnostic.Code}: {diagnostic.Message} {Environment.NewLine} {diagnostic.Description} in position {diagnostic.Start} - {diagnostic.End}");
                            break;
                        default:
                            this.WriteInformation($"{diagnostic.Code}: {diagnostic.Message} {Environment.NewLine} {diagnostic.Description} in position {diagnostic.Start} - {diagnostic.End}", null);
                            break;
                    }
                }
            }
            else
            {
                throw new CmdletInvocationException("Kql Expression is null or empty");
            }
        }
        #endregion
    }
}
