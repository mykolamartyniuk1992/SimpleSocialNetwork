using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;

namespace SimpleSocialNetwork.Api.Services
{
    public class EmailService
    {
        private readonly IConfiguration _configuration;
        private readonly string _smtpHost;
        private readonly int _smtpPort;
        private readonly string _smtpUser;
        private readonly string _smtpPass;
        private readonly string _fromEmail;

        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
            _smtpHost = _configuration["Email:SmtpHost"];
            _smtpPort = int.Parse(_configuration["Email:SmtpPort"]);
            _smtpUser = _configuration["Email:SmtpUser"];
            _smtpPass = _configuration["Email:SmtpPass"];
            _fromEmail = _configuration["Email:FromEmail"];
        }

        public void SendVerificationEmail(string toEmail, string verificationLink)
        {
            var message = new MailMessage();
            message.From = new MailAddress(_fromEmail);
            message.To.Add(new MailAddress(toEmail));
            message.Subject = "Verify your account";
            message.Body = $"Please verify your account by clicking the link: {verificationLink}";
            message.IsBodyHtml = false;

            using (var client = new SmtpClient(_smtpHost, _smtpPort))
            {
                client.EnableSsl = true;
                client.Credentials = new NetworkCredential(_smtpUser, _smtpPass);
                client.Send(message);
            }
        }
    }
}
