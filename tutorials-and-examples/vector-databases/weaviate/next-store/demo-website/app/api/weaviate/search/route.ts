import { NextRequest, NextResponse } from "next/server";
const https = require("https");
import client from "@/app/lib/weaviate-client";

/* Function to perform near text search with filtering*/

export async function GET(request: NextRequest) {
    
  try {
    const search = request.nextUrl.searchParams.get("s") || "";
    const filter = request.nextUrl.searchParams.get("f") || "";
    console.log("search", search, filter)
    let searchResults =""
//@ts-ignore
if(filter?.length>0){
    console.log("search with filter")
    //@ts-ignore
  searchResults = await nearTextQuery(search, filter);

}else{
    console.log("search without filter")
    searchResults= await nearTextQueryNoFilter(search);

}

    return NextResponse.json(searchResults);
  } catch (error) {
    console.log(error);
    return NextResponse.json(
      { error: "Internal Server Error" },
      { status: 500 }
    );
  }
}

async function nearTextQuery(term : string, filter: string) {
  let result;

  result = await client.graphql
    .get()
    .withClassName("Products")
    //@ts-ignore
    .withNearText({ concepts: [term] })
    .withWhere({
        path: ['category'],
        operator: 'Equal',
        valueText: filter,
      })
    .withLimit(2)
    .withFields("title link description _additional{id}")
    .do();

  return result.data.Get.Products;
}

async function nearTextQueryNoFilter(term : string) {
    let result;
  
    result = await client.graphql
      .get()
      .withClassName("Products")
      //@ts-ignore
      .withNearText({ concepts: [term] })
      .withLimit(2)
      .withFields("title link description _additional{id}")
      .do();

      
  
    return result.data.Get.Products;
  }
