"use client";
import axios from "axios";
import React, { useEffect, useState } from "react";
import Product from "@/app/components/Product";


interface ProductObj {
  description: String;
  name: String;
  link: String;
  id: String;
}

let blankProduct : ProductObj = {
  description: "",
  name: "",
  link: "",
  id: "",
}; 
const page = () => {
  





  return (
    <>
      <Product productObj={blankProduct}  />
     
    </>
  );
};
export default page;
