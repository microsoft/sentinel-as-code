using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Diagnostics;
using System.Linq;
using System.Management.Automation;

namespace Azure.Kql.Powershell.Tests
{
    [TestClass]
    public class KqlPowershellTests
    {
        [TestMethod]
        public void TestCaseWellExpression()
        {
            KqlValidatorCommand command = new KqlValidatorCommand()
            {
                KQLExpression = "T | project a = a + b | where a > 10.0"
            };

            command.Invoke().OfType<string>().ToList();
        }

        [TestMethod]
        public void TestCaseBadExpression()
        {
            KqlValidatorCommand command = new KqlValidatorCommand()
            {
                KQLExpression = "T | proyect a = a + b | whee a > 10.0"
            };

            Assert.ThrowsException<KqlValidationException>(() => command.Invoke().OfType<string>().ToList());
        }

        [TestMethod]
        public void TestCaseNullExpression()
        {
            KqlValidatorCommand command = new KqlValidatorCommand()
            {
                KQLExpression = null
            };

            Assert.ThrowsException<CmdletInvocationException>(() => command.Invoke().OfType<string>().ToList());
        }

        [TestMethod]
        public void TestCaseEmptyExpression()
        {
            KqlValidatorCommand command = new KqlValidatorCommand()
            {
                KQLExpression = ""
            };

            Assert.ThrowsException<CmdletInvocationException>(() => command.Invoke().OfType<string>().ToList());
        }
    }
}