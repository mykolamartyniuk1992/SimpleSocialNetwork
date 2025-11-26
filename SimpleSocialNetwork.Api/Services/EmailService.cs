
using Microsoft.Extensions.Configuration;
using Google.Cloud.SecretManager.V1;
using Resend;
using System.Threading.Tasks;

namespace SimpleSocialNetwork.Api.Services
{
    public class EmailService
    {

        private readonly IConfiguration _configuration;
        private readonly string? _resendApiKey;
        private readonly string? _fromEmail;
        private readonly IResend _resendClient;


        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
            var projectId = _configuration["Email:ProjectId"];
            if (string.IsNullOrEmpty(projectId))
                throw new ArgumentNullException(nameof(projectId), "ProjectId is not configured in appsettings.");
            _resendApiKey = GetSecret($"projects/{projectId}/secrets/resend-email-api-key/versions/latest");
            _fromEmail = _configuration["Email:FromEmail"];
            if (string.IsNullOrEmpty(_resendApiKey))
                throw new ArgumentNullException(nameof(_resendApiKey), "Resend API key is not configured.");
            if (string.IsNullOrEmpty(_fromEmail))
                throw new ArgumentNullException(nameof(_fromEmail), "From email is not configured.");
            _resendClient = ResendClient.Create(_resendApiKey);
        }

        private string GetSecret(string secretName)
        {
            var client = SecretManagerServiceClient.Create();
            var result = client.AccessSecretVersion(secretName);
            return result.Payload.Data.ToStringUtf8();
        }



        public async Task SendVerificationEmailAsync(string toEmail, string verificationLink)
        {
            if (_fromEmail == null) throw new InvalidOperationException("From email is not set.");

            var message = new EmailMessage
            {
                From = _fromEmail,
                To = toEmail,
                Subject = "Verify your account",
                HtmlBody = $"<p>Please verify your account by clicking the link: <a href='{verificationLink}'>Verify</a></p>"
            };

            try
            {
                await _resendClient.EmailSendAsync(message);
            }
            catch (Exception ex)
            {
                throw new Exception($"Failed to send email: {ex.Message}", ex);
            }
        }
    }
}
