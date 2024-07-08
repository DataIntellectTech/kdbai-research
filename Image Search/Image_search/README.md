# KDB.AI and Medical Imaging

This folder contains the work of Jude Reilly evaluating the accuracy of of KDB.AI in identifying brain tumours and lung diseases, including COVID-19, from X-ray scans. This involves training a neural network on a dataset from Kaggle and evaluating its accuracy using various similarity metrics and indexing methods. The results indicate that KDB.AI can significantly aid in medical diagnostics, potentially improving accuracy and efficiency in healthcare.

The data available in this folder has already been split using the [splitter notebook](https://github.com/DataIntellectTech/kdbai-research/blob/main/Image%20Search/Image_search/COVID-data-splitter.ipynb), however this can be used for future datasets.

You will need to train a neural network to run these notebooks. You can do so with the [COVID_model_training](https://github.com/DataIntellectTech/kdbai-research/blob/main/Image%20Search/Image_search/COVID_model_training.ipynb) notebook.

Once you have a neural network setup you can work through the [KDBAI_Image_Search_Showcase.ipynb](https://github.com/DataIntellectTech/kdbai-research/blob/main/Image%20Search/Image_search/KDBAI_Image_Search_Showcase.ipynb).

For more information checkout [Jude's blog](https://dataintellect.com/blog/kdb-ai-a-breath-of-fresh-air/).
