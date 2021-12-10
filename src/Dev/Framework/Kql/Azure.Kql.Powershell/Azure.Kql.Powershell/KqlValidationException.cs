using Kusto.Language;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Azure.Kql.Powershell
{
    public class KqlValidationException : Exception
    {
        #region · Public ·
        public KqlValidationException(Diagnostic diagnostic) : base($"{diagnostic.Code}: {diagnostic.Message} {Environment.NewLine} {diagnostic.Description} in position {diagnostic.Start} - {diagnostic.End}")
        {

        }
        #endregion
    }
}
