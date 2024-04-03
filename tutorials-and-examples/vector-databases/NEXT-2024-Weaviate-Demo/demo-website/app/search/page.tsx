"use client";
import axios from "axios";
import React, { useEffect, useState } from "react";
import Link from "next/link";

interface Product {
  description: String;
  name: String;
  id: String;
  link: String;
  _additional: {
    id: String;
  };
}

const page = () => {
  const [resultsAry, setResultsAry] = useState([]);

  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("");

  const productSearch = async () => {
    axios
      .get("/api/weaviate/search?s=" + search + "&f=" + category)
      .then((response) => {
        // Handle successful response
        console.log("Response data:", response.data);
        setResultsAry(response.data);
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
    <>
      <h1 className="font-bold text-3xl mb-2 mt-3">Search</h1>

      <div className="relative inline-block text-black text-left">
        <ul>
          <li>
            <label className="text-black">Search Term:</label>{" "}
            <input
              id="search"
              name="search"
              className="bg-gray-100 w-96 m-2 p-1 border text-black"
              onChange={(event) => setSearch(event.target.value)}
              //@ts-ignore
              value={search}
            />
          </li>
          <li>
            <label className="text-black">Choose a Category:</label>
            <select
              id="category"
              name="category"
              className="w-24  m-2 p-1 border text-black"
              onChange={(event) => setCategory(event.target.value)}
              //@ts-ignore
              value={category}
            >
              <option value="" defaultValue=""></option>
              <option value="Clothing">Clothing</option>
              <option value="Hoodies">Hoodies</option>
              <option value="Sweatshirts">Sweatshirts</option>
              <option value="accessories">accessories</option>
              <option value="Tops">Tops</option>
              <option value="Tshirts">Tshirts</option>
              <option value="Tees">Tees</option>
            </select>
          </li>
          <li>
            {" "}
            <button
              type="submit"
              onClick={productSearch}
              className="bg-indigo-500 border text-white mb-2 mt-3 hover:bg-grey-300 ld py-2 px-4 rounded"
            >
              Search
            </button>
          </li>
        </ul>
      </div>

      <div className="w-full ">
        {resultsAry.length >= 1 ? (
          <>
            <h1 className="text-black">Product List ({resultsAry.length})</h1>
            <div className="grid grid-cols-1 w-full md:grid-cols-4 p-3 ml-2 mr-2">
              {resultsAry.map((product: Product, index) => (
                <div
                  key={index}
                  className="m-2 p-1 text-center mx-auto hover:border-gray-500 hover:border"
                >
                  <Link
                    href={
                      // @ts-ignore
                      "/product/?id=" + product._additional.id
                    }
                  >
                    <span className="text-lg font-bold text-black">
                      {
                        // @ts-ignore
                        product.title
                      }
                    </span>
                    <span>
                      <img
                        className="mx-auto   h-96 md:h-auto sm-h-50  "
                        src={`${product.link}`}
                        alt="filename"
                      />
                    </span>

                    <p className="text-black">
                      {
                        // @ts-ignore
                        product.description
                          ? product.description.length > 90
                            ? product.description.substring(0, 90) + "..."
                            : product.description
                          : null
                      }
                    </p>
                  </Link>
                </div>
              ))}
            </div>
          </>
        ) : null}
      </div>
    </>
  );
};
export default page;
