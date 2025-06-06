import os
import asyncio

from semantic_kernel.agents import AgentGroupChat, ChatCompletionAgent
from semantic_kernel.agents.strategies.termination.termination_strategy import TerminationStrategy
from semantic_kernel.agents.strategies.selection.kernel_function_selection_strategy import (
    KernelFunctionSelectionStrategy,
)
from semantic_kernel.connectors.ai.function_choice_behavior import FunctionChoiceBehavior
from semantic_kernel.connectors.ai.open_ai.services.azure_chat_completion import AzureChatCompletion
from semantic_kernel.contents.chat_message_content import ChatMessageContent
from semantic_kernel.contents.utils.author_role import AuthorRole
from semantic_kernel.kernel import Kernel


class ApprovalTerminationStrategy(TerminationStrategy):
    """A strategy for determining when an agent should terminate."""
 
    async def should_agent_terminate(self, agent, history):
        """Check if the agent should terminate."""
        # Termina quando il Product Owner dice "READY FOR USER APPROVAL"
        if history:
            last_message = history[-1]
            if (hasattr(last_message, 'content') and 
                'READY FOR USER APPROVAL' in str(last_message.content)):
                return True
        return False


async def create_agents(kernel: Kernel):
    """Crea i tre agenti con le rispettive persona."""
    
    # Business Analyst Agent
    business_analyst = ChatCompletionAgent(
        service_id="chat-completion",
        kernel=kernel,
        name="BusinessAnalyst",
        instructions="""You are a Business Analyst which will take the requirements from the user (also known as a 'customer') and create a project plan for creating the requested app. The Business Analyst understands the user requirements and creates detailed documents with requirements and costing. The documents should be usable by the SoftwareEngineer as a reference for implementing the required features, and by the Product Owner for reference to determine if the application delivered by the Software Engineer meets all of the user's requirements."""
    )
    
    # Software Engineer Agent
    software_engineer = ChatCompletionAgent(
        service_id="chat-completion",
        kernel=kernel,
        name="SoftwareEngineer",
        instructions="""You are a Software Engineer, and your goal is create a web app using HTML and JavaScript by taking into consideration all the requirements given by the Business Analyst. The application should implement all the requested features. Deliver the code to the Product Owner for review when completed. You can also ask questions of the BusinessAnalyst to clarify any requirements that are unclear."""
    )
    
    # Product Owner Agent
    product_owner = ChatCompletionAgent(
        service_id="chat-completion",
        kernel=kernel,
        name="ProductOwner",
        instructions="""You are the Product Owner which will review the software engineer's code to ensure all user requirements are completed. You are the guardian of quality, ensuring the final product meets all specifications. IMPORTANT: Verify that the Software Engineer has shared the HTML code using the format ```html [code] ```. This format is required for the code to be saved and pushed to GitHub. Once all client requirements are completed and the code is properly formatted, reply with 'READY FOR USER APPROVAL'. If there are missing features or formatting issues, you will need to send a request back to the SoftwareEngineer or BusinessAnalyst with details of the defect."""
    )
    
    return business_analyst, software_engineer, product_owner


async def run_multi_agent(input: str):
    """Implement the multi-agent system."""
    
    # Crea il kernel
    kernel = Kernel()
    
    # Aggiungi il servizio di chat completion (devi configurare Azure OpenAI)
    chat_service = AzureChatCompletion(
        service_id="chat-completion",
        # Aggiungi qui i tuoi parametri di configurazione Azure
        # deployment_name="your-deployment-name",
        # endpoint="your-endpoint",
        # api_key="your-api-key",
    )
    kernel.add_service(chat_service)
    
    # Crea gli agenti
    business_analyst, software_engineer, product_owner = await create_agents(kernel)
    
    # Crea la strategia di terminazione
    termination_strategy = ApprovalTerminationStrategy()
    
    # Crea la strategia di selezione (round-robin o basata su funzioni)
    selection_strategy = KernelFunctionSelectionStrategy()
    
    # Crea il gruppo di chat degli agenti
    agent_group_chat = AgentGroupChat(
        agents=[business_analyst, software_engineer, product_owner],
        selection_strategy=selection_strategy,
        termination_strategy=termination_strategy
    )
    
    # Aggiungi il messaggio iniziale dell'utente
    await agent_group_chat.add_chat_message(
        ChatMessageContent(role=AuthorRole.USER, content=input)
    )
    
    # Esegui la conversazione tra gli agenti
    responses = []
    async for response in agent_group_chat.invoke():
        responses.append(response)
        print(f"{response.name}: {response.content}")
    
    return responses


# Esempio di utilizzo
async def main():
    user_input = "I need a simple calculator web app that can perform basic arithmetic operations (addition, subtraction, multiplication, division)"
    
    responses = await run_multi_agent(user_input)
    
    print("\n=== CONVERSATION COMPLETED ===")
    for response in responses:
        print(f"{response.name}: {response.content}")


if __name__ == "__main__":
    asyncio.run(main())