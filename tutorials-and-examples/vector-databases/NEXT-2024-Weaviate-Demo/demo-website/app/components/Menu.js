import React from 'react'
import Link from "next/link";
const Menu = () => {
  return (
    <div className="mb-2">
            <Link href="/" ><span className="font-bold text-blue-600"> View Products</span> </Link> |

      <Link href="/createproduct" ><span className="font-bold text-blue-600 m-2">Create Product</span> </Link> |
      <Link href="/search" ><span className="font-bold text-blue-600 m-2">Search</span> </Link> 

    </div>
  )
}

export default Menu
