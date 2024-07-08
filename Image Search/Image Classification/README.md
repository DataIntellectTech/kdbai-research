# Image Classification

This folder contains the work of Paul McVicker on image classification using KDB.AI. This involves the creation of vector embeddings for test images which are then compared to vector embeddings of a larger data set created by a pre-trained neural network. This will then return a classification based on the classifications of the test embedding's nearest neighbours.

Initially users will work through the [classification_doc.ipynb notebook](https://github.com/paul-mcvicker/kdbai-research/blob/main/Image%20Search/Image%20Classification/classification_doc.ipynb). Note, this notebook will require a previously trained neural network. If you have not done this, you can train one using this [training notebook](https://github.com/DataIntellectTech/kdbai-research/blob/main/Image%20Search/Image_search/COVID_model_training.ipynb). 

If you want to test how many neighbours to compare to is the best for your neural network, you can use [this notebook](https://github.com/paul-mcvicker/kdbai-research/blob/main/Image%20Search/Image%20Classification/search_length_testing-Copy1.ipynb).

For more information checkout [Paul's blog](https://dataintellect.com/blog/image-classification-with-kdb-ai/).
