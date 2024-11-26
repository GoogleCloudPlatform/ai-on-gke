"use client";
import axios from "axios";
import React, { useEffect, useState } from "react";
import Product from "@/app/components/Product";

const page = ({ searchParams }) => {
  const productId = searchParams.id;
  const [product, setProduct] = useState({});

  useEffect(() => {
    if (productId) {
      getProduct(productId);
    }
  }, []);

  const getProduct = async (productId) => {
    axios
      .get("/api/weaviate?pid=" + productId)
      .then((response) => {
        // Handle successful response
        console.log("Response data:", response.data);
        let product = response.data;
        product["id"] = productId;
        setProduct(response.data);
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
      <Product productObj={product} />
    </>
  );
};
export default page;
