import { NextRequest, NextResponse } from "next/server";
import { writeFile } from "fs/promises";
import { join } from "path";

export async function POST(request: NextRequest) {
  const data = await request.formData();
  const file: File | null = data.get("file") as unknown as File;

  if (!file) {
    return NextResponse.json(
      { error: "Internal Server Error" },
      { status: 500 }
    );
  }

  const bytes = await file.arrayBuffer();
  const buffer = Buffer.from(bytes);

  try {
    //await uploadToGCS(file, buffer);
    const { Storage } = require("@google-cloud/storage");
    const storage = new Storage();
    console.log("Uploading file to GCS...");

   await storage
      .bucket(process.env.GCS_BUCKET)
      .file(file.name)
      .save(Buffer.from(buffer))
      
    console.log("File uploaded complete");
    return NextResponse.json({
        link:
          "https://storage.googleapis.com/" +
          process.env.GCS_BUCKET +
          "/" +
          file.name,
      })
  } catch (error) {
    console.log(error);
    return NextResponse.json(
      { error: "Internal Server Error" },
      { status: 500 }
    );
  }
}

// const uploadToGCS = async (file: any, buffer: any) => {
//   const { Storage } = require("@google-cloud/storage");
//   const storage = new Storage();
//   console.log("Uploading file to GCS...");

//   let result = await storage
//     .bucket(process.env.GCS_BUCKET)
//     .file(file.name)
//     .save(Buffer.from(buffer))
//     .catch(console.error, console.log("file upload failed"))
//     .then(() => {
//       console.log("File uploaded to GCS");
//     });
// };

