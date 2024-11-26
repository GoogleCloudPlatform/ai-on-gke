"use client";
import React, { useState, useEffect } from "react";
import axios from "axios";
import Link from "next/link";

interface ProductObj {
  description: String;
  name: String;
  link: String;
  id: String;
}

const Product = ({ productObj }: { productObj: ProductObj }) => {
  const [file, setFile] = useState<File | undefined>();
  const [link, setLink] = useState("");
  const [product, setProduct] = useState({});

  const [title, setTitle] = useState("");
  const [loadingDesc, setLoadingDesc] = useState(false);
  const [loadingImg, setLoadingImg] = useState(false);
  const [category, setCategory] = useState("");
  const [description, setDescription] = useState("");
  useEffect(() => {
    //@ts-ignore
    setTitle(productObj.title);
    //@ts-ignore
    setDescription(productObj.description);
    //@ts-ignore
    setLink(productObj.link);
    //@ts-ignore
    setCategory(productObj.category);

    console.log(productObj);
  }, [productObj]);

  function handleChange(e: React.FormEvent<HTMLInputElement>) {
    const target = e.target as HTMLInputElement & {
      files: FileList;
    };
    setFile(target.files[0]);
  }

  function uploadImage(e: React.SyntheticEvent) {
    e.preventDefault();
    setLoadingImg(true);

    const url = "api/upload";
    const formData = new FormData();
    // @ts-ignore comment
    formData.append("file", file);
    // @ts-ignore comment
    formData.append("link", file.name);
    const config = {
      headers: {
        "content-type": "multipart/form-data",
      },
    };
    axios
      .post(url, formData, config)
      .then((response) => {
        console.log("uploaded", response.data.link);
        setLink(response.data.link);
      })
      .catch((error) => {
        console.error(error);
      })
      .finally(() => {
        setLoadingImg(false);
      });
  }

  function generateDesc() {
    setLoadingDesc(true);
    const data = {
      title: title,
      link: link,
    };
    const headers = {
      "Content-Type": "application/json",
    };
    axios
      .post("/api/gemini", data, { headers })
      .then((response) => {
        console.log(response.data); // Contains the response from the server
        setDescription(response.data.description);
      })
      .catch((error) => {
        console.error(error);
      })
      .finally(() => {
        setLoadingDesc(false);
      });
  }
  function createProduct() {
    let productData = {
      title: title,
      category: category,
      description: description,
      link: link,
    };

    axios
      .post("/api/weaviate", productData)
      .then(function (response) {
        console.log(response);
        if (response.status === 200) {
          window.location.href = "/";
        }
      })
      .catch(function (error) {
        console.log(error);
      });
  }

  function saveProduct() {
    let productData = {
      title: title,
      category: category,
      description: description,
      link: link,
      productId: productObj.id,
    };

    axios
      .patch("/api/weaviate", productData)
      .then(function (response) {
        console.log(response);
        if (response.status === 200) {
          window.location.href = "/";
        }
      })
      .catch(function (error) {
        console.log(error);
      });
  }

  const deleteProduct = () => {
    axios
      .delete("/api/weaviate?pid=" + productObj.id)
      .then((response) => {
        // Handle successful response
        console.log("Response data:", response.data);

        if (response.status === 200) {
          window.location.href = "/";
        }
      })
      .catch((error) => {
        // Handle error
        if (error.response) {
          // The request was made and the server responded with a status code
          // that falls out of the range of 2xx
          console.error("Error status:", error.response.status);
          console.error("Error data:", error.response.data);
        } else if (error.request) {
          // The request was made but no response was received
          console.error("No response received:", error.request);
        } else {
          // Something happened in setting up the request that triggered an Error
          console.error("Error:", error.message);
        }
      });
  };
  return (
    <div className="pl-5">
      <h1 className="text-2xl">Product Page</h1>
      <div className="flex flex-col justify-between p-4 leading-normal">
        <form onSubmit={uploadImage}>
          <ul>
            <li>
              Title:{" "}
              <input
                className="bg-gray-100 w-96 m-2 p-1"
                //@ts-ignore
                onChange={(event) => setTitle(event.target.value)}
                //@ts-ignore
                value={title}
              />
            </li>
            <li>
              Category:{" "}
              <input
                className="bg-gray-100 w-96 m-2 p-1"
                //@ts-ignore
                onChange={(event) => setCategory(event.target.value)}
                //@ts-ignore
                value={category}
              />
            </li>
            <li>
              Image:{" "}
              <input
                type="file"
                className="w-64"
                name="file"
                onChange={handleChange}
              />
              {loadingImg ? (
                <div
                  className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-current border-e-transparent align-[-0.125em] text-surface motion-reduce:animate-[spin_1.5s_linear_infinite] dark:text-white"
                  role="status"
                >
                  <span className="!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]">
                    Loading...
                  </span>
                </div>
              ) : (
                <button
                  type="submit"
                  className="bg-green-500 text-white hover:bg-grey-300 ld py-2 px-4 rounded"
                >
                  Upload
                </button>
              )}
            </li>
          </ul>
          {link ? (
            <img
              className="object-cover w-full rounded-t-lg h-96 md:h-auto md:w-48 md:rounded-none md:rounded-s-lg"
              src={`${link}`}
              alt="link"
            />
          ) : null}
        </form>
        <div className="w-96 mt-2">
          {loadingDesc ? (
            <div
              className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-current border-e-transparent align-[-0.125em] text-surface motion-reduce:animate-[spin_1.5s_linear_infinite] dark:text-white"
              role="status"
            >
              <span className="!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]">
                Loading...
              </span>
            </div>
          ) : (
            <button
              type="submit"
              onClick={generateDesc}
              className="bg-indigo-500 text-white mb-2 mt-3 hover:bg-grey-300 ld py-2 px-4 rounded"
            >
              Generate Product Description
            </button>
          )}

          <textarea
            // @ts-ignore comment

            value={description}
            //@ts-ignore
            onChange={(event) => setDescription(event.target.value)}
            name="description"
            className="block p-2.5 w-full 
                text-gray-900 bg-gray-50 
                rounded-lg border border-gray-300 
                focus:ring-blue-500 
                focus:border-blue-500 
               "
            placeholder="Write your item description..."
            // @ts-ignore comment
            rows="6"
          ></textarea>
          {productObj.id ? (
            <>
              <button
                type="submit"
                onClick={saveProduct}
                className="bg-blue-500 text-white mb-2 mt-3 hover:bg-grey-300 ld py-2 px-4 rounded"
              >
                Save Product
              </button>
              <Link
                href="/"
                onClick={deleteProduct}
                className=" text-red mb-2 mt-3  py-2 px-4"
              >
                Delete Product
              </Link>
            </>
          ) : (
            <button
              type="submit"
              onClick={createProduct}
              className="bg-blue-500 text-white mb-2 mt-3 hover:bg-grey-300 ld py-2 px-4 rounded"
            >
              Create Product
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default Product;
