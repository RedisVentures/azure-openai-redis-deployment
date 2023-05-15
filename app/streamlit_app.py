import streamlit as st
import os
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient
from PyPDF2 import PdfReader
# Import
#import textwrap
import openai
from langchain.llms import AzureOpenAI, OpenAI
from langchain.embeddings import OpenAIEmbeddings
from llama_index.vector_stores import RedisVectorStore
from llama_index import LangchainEmbedding
from llama_index import (
    GPTVectorStoreIndex,
    SimpleDirectoryReader,
    LLMPredictor,
    PromptHelper,
    ServiceContext,
    StorageContext
)

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")

OPENAI_API_TYPE = os.getenv("OPENAI_API_TYPE", "")
OPENAI_COMPLETIONS_ENGINE = os.getenv("OPENAI_COMPLETIONS_ENGINE", "text-davinci-003")
OPENAI_EMBEDDINGS_ENGINE = os.getenv("OPENAI_EMBEDDINGS_ENGINE", "text-embedding-ada-002")


STORAGE_CONNECTION_STRING=os.getenv("STORAGE_CONNECTION_STRING", "")
CONTAINER_NAME=os.getenv("CONTAINER_NAME", "data")

def get_embeddings():
    if OPENAI_API_TYPE=="azure":
        #currently Azure OpenAI embeddings require request for service limit increase to be useful
        #using build-in HuggingFace instead
        #from langchain.embeddings import HuggingFaceEmbeddings
        #embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
        from langchain.embeddings import OpenAIEmbeddings
        embeddings = OpenAIEmbeddings(deployment=OPENAI_EMBEDDINGS_ENGINE, chunk_size=1 )
    else:
        from langchain.embeddings import OpenAIEmbeddings
        # Init OpenAI Embeddings
        embeddings = OpenAIEmbeddings()
    return embeddings 

def get_llm():
    if OPENAI_API_TYPE=="azure":
        from langchain.llms import AzureOpenAI
        llm=AzureOpenAI(deployment_name=OPENAI_COMPLETIONS_ENGINE)
    else:
        from langchain.llms import OpenAI
        llm=OpenAI()
    return llm


@st.cache_resource
def get_query_engine():

    blob_service_client = BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
    container_client = blob_service_client.get_container_client(container=CONTAINER_NAME)
    download_file_path = "/tmp/docs"
    isExist = os.path.exists(download_file_path)
    if not isExist:
        os.makedirs(download_file_path)

    # List the blobs in the container
    blob_list = container_client.list_blobs()
    for blob in blob_list:
        print("\t" + blob.name)
        if not os.path.exists( download_file_path+ "/" + blob.name): 
            print("\nDownloading blob to \n\t" + download_file_path+ "/" + blob.name)
            with open(file=download_file_path + "/" + blob.name, mode="wb") as download_file:
                download_file.write(container_client.download_blob(blob.name).readall())
        else:
            print("\nSkipping \n\t" + download_file_path+ "/" + blob.name)

    # load documents
    documents = SimpleDirectoryReader(download_file_path).load_data()
    print('Document ID:', documents[0].doc_id, 'Document Hash:', documents[0].doc_hash)


    from llama_index.storage.storage_context import StorageContext

    vector_store = RedisVectorStore(
        index_name="chevy_docs",
        index_prefix="llama",
        redis_url="rediss://default:{}@{}:{}".format(REDIS_PASSWORD,REDIS_HOST,REDIS_PORT),
        overwrite=True
    )

    llm_predictor = LLMPredictor(llm=get_llm())
    llm_embedding = LangchainEmbedding(get_embeddings())
    service_context = ServiceContext.from_defaults(
        llm_predictor=llm_predictor,
        embed_model=llm_embedding,
    )
    storage_context = StorageContext.from_defaults(vector_store=vector_store)
    index = GPTVectorStoreIndex.from_documents(documents, storage_context=storage_context, service_context=service_context)


    return index.as_query_engine()

file = open("assets/app-info.md", "r")
st.markdown(file.read())
query_engine = get_query_engine()
user_query = st.text_input("Query:", 'What types of variants are available for the Chevrolet Colorado?')
try:
    response = query_engine.query(user_query)
except:
    st.markdown("")
st.markdown(str(response))
print(str(response))