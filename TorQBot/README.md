# Create a TorQ support bot named TESS using Retrieval Augmented Generation along side KDB.AI and ChatGPT.

This folder contains the original notebook creating TESS as well as numerous upgrades discussed [here](https://dataintellect.com/news/tess-again/?preview=true). This folder contains notebooks developed by Ciarán Ó Donnaile, James Cormican, and Lughán Devenny.

Readers should at this stage be familiar with KDB.AI and OpenAI, however for those unfamiliar with the RAG framework it is essentially a framework that enables LLM's to access relevant data from external knowledge bases, enriching their responses with current and contextually accurate information. For more information on RAG you can check out KX's videos on [youtube](https://www.youtube.com/@KxSystems/featured).

It is possible to merge all of these upgrades into a single bot, however this can be very heavy on API calls and cost a lot of money and/or exceed your API rate limits. 

Some features to implement in the future:
* User specific chat history
* Optimise embedding within RAG framework
* Source citation
* Caching frequent queries as FAQ's
* Develop a front end user interface

