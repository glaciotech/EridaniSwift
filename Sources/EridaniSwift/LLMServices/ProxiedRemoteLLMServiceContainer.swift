//
//  ProxiedRemoteLLMServiceContainer.swift
//  EridaniSwift
//
//  Created by Peter Liddle on 9/13/25.
//

import Foundation

public class ProxiedRemoteLLMServiceContainer: RemoteLLMServiceContainer {
    
    let sessionRefreshHandler: ProxySessionHandler?
    
    public init(withProxy proxy: ProxyDetails, sessionRefreshHandler: ProxySessionHandler) {
        
        let accessToken = proxy.authToken.accessToken
        let proxyUrl = proxy.proxyUrl
    
        let openAIService = OpenAIService(baseUrl: proxyUrl + "/openai", apiKey: accessToken, proxyAppAPIKey: proxy.proxyAppApiKey, sessionRefreshHandler: sessionRefreshHandler)
        let anthropicService = AnthropicService(baseUrl: proxyUrl + "/anthropic", apiKey: accessToken, proxyAppAPIKey: proxy.proxyAppApiKey, sessionRefreshHandler: sessionRefreshHandler)
        let xAIService = XAiService(baseUrl: proxyUrl + "/xai", apiKey: accessToken, proxyAppAPIKey: proxy.proxyAppApiKey, sessionRefreshHandler: sessionRefreshHandler)
        let inceptionService = InceptionService(baseUrl: proxyUrl + "/inception", apiKey: accessToken, proxyAppAPIKey: proxy.proxyAppApiKey, sessionRefreshHandler: sessionRefreshHandler)
        
        self.sessionRefreshHandler = sessionRefreshHandler
        
        super.init(openAIService: openAIService, anthropicService: anthropicService, xAIService: xAIService, inceptionService: inceptionService)
    }
    
    public override func areApiKeysSetup(forModel model: RemoteLLMModel) throws(RemoteLLMServiceError) -> Bool {
        // This is irrelevant for the proxy
        return true
    }
}
