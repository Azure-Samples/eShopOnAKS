using Microsoft.AspNetCore.Mvc;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.AI.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.AI.OpenAI.ChatCompletion;
using Microsoft.SemanticKernel.Memory;

var builder = WebApplication.CreateBuilder(args);

// Add configuration
builder.Configuration
  .AddJsonFile("appsettings.local.json", optional: true)
  .AddEnvironmentVariables();

// Azure OpenAI settings
var aoaiSettings = builder.Configuration.GetSection("AzureOpenAISettings").Get<AzureOpenAISettings>();

// Azure OpenAI via SemanticKernel
var kernel = Kernel.Builder
  .Configure(c => 
  {
    c.AddAzureChatCompletionService(
      aoaiSettings.ChatCompletionModel.Alias,
      aoaiSettings.ChatCompletionModel.DeploymentName,
      aoaiSettings.Endpoint,
      aoaiSettings.Key);
    c.AddAzureTextEmbeddingGenerationService(
      aoaiSettings.EmbeddingGenerationModel.Alias,
      aoaiSettings.EmbeddingGenerationModel.DeploymentName,
      aoaiSettings.Endpoint,
      aoaiSettings.Key
    );
  })
  .WithMemoryStorage(new VolatileMemoryStore())
  .Build();

builder.Services.AddSingleton<IKernel>(kernel);

builder.Services.AddCors();

var app = builder.Build();

app.UseCors(builder => builder
  .AllowAnyOrigin()
  .AllowAnyMethod()
  .AllowAnyHeader()
);

app.MapGet("/", () => "eShopBot v1.0");

app.MapPost("/", async ([FromServices]IKernel kernel, [FromBody]ChatRequest req) => {
  var chatGPT = kernel.GetService<IChatCompletion>();

  var systemMessage = @"You are chatting with a potential customers of your store which sells the following products:
    .NET Bot Black Sweatshirt
    .NET Black & White Mug
    Prism White T-Shirt
    .NET Foundation Sweatshirt
    Roslyn Red Sheet
    .NET Blue Sweatshirt
    Roslyn Red T-Shirt
    Kudu Purple Sweatshirt
    Cup<T> White Mug
    .NET Foundation Sheet
    Cup<T> Sheet
    Prism White TShirt
    ";

  var chat = (OpenAIChatHistory)chatGPT.CreateNewChat(systemMessage);

  // add the user's message
  chat.AddUserMessage(req.Text);

  // remind the user to only ask about the products
  chat.AddSystemMessage("Kindly decline not to answer any questions not related to the products you sell.");

  // get the bot's response
  string response = await chatGPT.GenerateMessageAsync(chat, new ChatRequestSettings());
  chat.AddAssistantMessage(response);
  
  return Results.Ok("eShopBot: " + response);
});

app.Run();

public class ChatRequest
{
  public string Text { get; set; } = string.Empty;
}

public class AzureOpenAISettings
{
  public string Endpoint { get; set; } = string.Empty;
  public string Key { get; set; } = string.Empty;
  public ModelDeployment ChatCompletionModel { get; set; }
  public ModelDeployment EmbeddingGenerationModel { get; set; }
  public ModelDeployment TextCompletionModel { get; set; }
}

public struct ModelDeployment {
  public string Alias { get; set; }
  public string DeploymentName { get; set; }
}