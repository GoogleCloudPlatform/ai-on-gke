import { NextRequest, NextResponse } from "next/server";
const https = require("https");
import client from "@/app/lib/weaviate-client";
export const dynamic = 'force-dynamic'



/* Function to get all products */

export async function GET(request: NextRequest) {
  let result = await client.graphql
  .get()
  .withClassName("Products")
  .withFields("title description link    _additional { id }")
  .withLimit(200)
  .do();

  console.log("Get all products from weaviate");


  if (result) {
    return NextResponse.json(result.data.Get.Products);
  } else {
    return NextResponse.json({});
  }
}