import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
import tensorflow as tf
import numpy as np

strategy = tf.distribute.MirroredStrategy()
print('Number of devices: {}'.format(strategy.num_replicas_in_sync))

def scale(image):
    image = tf.cast(image, tf.float32)
    image /= 255

    return image

images_dir = "/data/mnist_predict/"

img_dataset = tf.keras.utils.image_dataset_from_directory(
    images_dir,
    image_size=(28, 28),
    color_mode="grayscale",
    label_mode=None, 
    labels=None,
    shuffle=False
)

file_paths = img_dataset.file_paths

img_prediction_dataset = img_dataset.map(scale)

model_path = '/data/mnist_saved_model/'

with strategy.scope():
    replicated_model = tf.keras.models.load_model(model_path)
    replicated_model.compile(
        loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        optimizer=tf.keras.optimizers.Adam(),
        metrics=['accuracy'])

    predictions = replicated_model.predict(img_prediction_dataset)
    scores = tf.nn.softmax(predictions)
    for path, score in zip(file_paths, scores):
        print(
            "The image {} is the number {} with a {:.2f} percent confidence."
            .format(path, np.argmax(score), 100 * np.max(score))
        )