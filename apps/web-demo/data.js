(function () {
  "use strict";

  window.WEARWISE_DEMO_DATA = {
  "presets": [
    [
      "First date",
      "smart_casual"
    ],
    [
      "Club presentation",
      "business"
    ],
    [
      "Friends dinner",
      "casual"
    ],
    [
      "Internship interview",
      "business"
    ],
    [
      "Night out",
      "casual"
    ]
  ],
  "garments": [
    {
      "id": "top-navy-striped-polo",
      "name": "Navy Striped Polo Shirt",
      "slot": "top",
      "category": "polo",
      "colors": [
        "Navy",
        "Cream",
        "Brown"
      ],
      "pattern": "Horizontal stripes",
      "fit": "Regular",
      "material": "Knit",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/top-navy-striped-polo.jpg",
      "fullPhoto": "assets/wardrobe/tops/top-navy-striped-polo.jpg"
    },
    {
      "id": "top-white-crew-tee",
      "name": "White Crew-neck T-shirt",
      "slot": "top",
      "category": "t_shirt",
      "colors": [
        "White"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Cotton",
      "formality": 1,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/top-white-crew-tee.jpg",
      "fullPhoto": "assets/wardrobe/tops/top-white-crew-tee.jpg"
    },
    {
      "id": "top-light-blue-graphic-tee",
      "name": "Light Blue Graphic T-shirt",
      "slot": "top",
      "category": "t_shirt",
      "colors": [
        "Light blue",
        "White"
      ],
      "pattern": "Graphic print",
      "fit": "Regular",
      "material": "Cotton",
      "formality": 1,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/top-light-blue-graphic-tee.jpg",
      "fullPhoto": "assets/wardrobe/tops/top-light-blue-graphic-tee.jpg"
    },
    {
      "id": "top-beige-half-zip",
      "name": "Stone Half-zip Sweatshirt",
      "slot": "top",
      "category": "pullover",
      "colors": [
        "Stone",
        "Light khaki"
      ],
      "pattern": "Solid",
      "fit": "Relaxed",
      "material": "Cotton blend",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/top-beige-half-zip.jpg",
      "fullPhoto": "assets/wardrobe/tops/top-beige-half-zip.jpg"
    },
    {
      "id": "bottom-light-gray-tailored-trousers",
      "name": "Light Gray Tailored Trousers",
      "slot": "bottom",
      "category": "trousers",
      "colors": [
        "Light gray"
      ],
      "pattern": "Solid",
      "fit": "Straight",
      "material": "Blend",
      "formality": 4,
      "formalityBand": "business",
      "photo": "assets/wardrobe/thumbnails/bottom-light-gray-tailored-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-light-gray-tailored-trousers.jpg"
    },
    {
      "id": "bottom-dark-blue-straight-jeans",
      "name": "Dark Blue Straight Jeans",
      "slot": "bottom",
      "category": "jeans",
      "colors": [
        "Dark blue"
      ],
      "pattern": "Washed denim",
      "fit": "Straight",
      "material": "Denim",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/bottom-dark-blue-straight-jeans.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-dark-blue-straight-jeans.jpg"
    },
    {
      "id": "bottom-navy-plaid-tailored-trousers",
      "name": "Navy Windowpane Trousers",
      "slot": "bottom",
      "category": "trousers",
      "colors": [
        "Navy",
        "Light blue"
      ],
      "pattern": "Windowpane check",
      "fit": "Slim straight",
      "material": "Wool blend",
      "formality": 4,
      "formalityBand": "business",
      "photo": "assets/wardrobe/thumbnails/bottom-navy-plaid-tailored-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-navy-plaid-tailored-trousers.jpg"
    },
    {
      "id": "bottom-light-gray-cargo-joggers",
      "name": "Light Gray Cargo Joggers",
      "slot": "bottom",
      "category": "cargo",
      "colors": [
        "Light gray"
      ],
      "pattern": "Solid",
      "fit": "Relaxed tapered",
      "material": "Cotton blend",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/bottom-light-gray-cargo-joggers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-light-gray-cargo-joggers.jpg"
    },
    {
      "id": "bottom-dark-brown-cargo-trousers",
      "name": "Dark Brown Cargo Trousers",
      "slot": "bottom",
      "category": "cargo",
      "colors": [
        "Dark brown",
        "Black"
      ],
      "pattern": "Solid",
      "fit": "Relaxed",
      "material": "Cotton",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/bottom-dark-brown-cargo-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-dark-brown-cargo-trousers.jpg"
    },
    {
      "id": "bottom-light-wash-wide-leg-jeans",
      "name": "Light Wash Wide-leg Jeans",
      "slot": "bottom",
      "category": "jeans",
      "colors": [
        "Light blue"
      ],
      "pattern": "Light wash",
      "fit": "Wide leg",
      "material": "Denim",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/bottom-light-wash-wide-leg-jeans.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-light-wash-wide-leg-jeans.jpg"
    },
    {
      "id": "bottom-charcoal-tapered-trousers",
      "name": "Charcoal Tapered Trousers",
      "slot": "bottom",
      "category": "trousers",
      "colors": [
        "Charcoal"
      ],
      "pattern": "Solid",
      "fit": "Tapered",
      "material": "Cotton blend",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/bottom-charcoal-tapered-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-charcoal-tapered-trousers.jpg"
    },
    {
      "id": "bottom-charcoal-wide-leg-trousers",
      "name": "Charcoal Wide-leg Trousers",
      "slot": "bottom",
      "category": "trousers",
      "colors": [
        "Charcoal"
      ],
      "pattern": "Solid",
      "fit": "Wide leg",
      "material": "Cotton blend",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/bottom-charcoal-wide-leg-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-charcoal-wide-leg-trousers.jpg"
    },
    {
      "id": "bottom-cream-linen-wide-leg-trousers",
      "name": "Cream Linen Wide-leg Trousers",
      "slot": "bottom",
      "category": "trousers",
      "colors": [
        "Cream",
        "Light beige"
      ],
      "pattern": "Solid",
      "fit": "Wide leg",
      "material": "Linen blend",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/bottom-cream-linen-wide-leg-trousers.jpg",
      "fullPhoto": "assets/wardrobe/bottoms/bottom-cream-linen-wide-leg-trousers.jpg"
    },
    {
      "id": "shoes-brown-shearling-boots",
      "name": "Brown Shearling Ankle Boots",
      "slot": "shoes",
      "category": "boots",
      "colors": [
        "Brown",
        "Cream"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Suede",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/shoes-brown-shearling-boots.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-brown-shearling-boots.jpg"
    },
    {
      "id": "shoes-cream-platform-sneakers",
      "name": "Cream Platform Sneakers",
      "slot": "shoes",
      "category": "sneakers",
      "colors": [
        "Cream",
        "Black"
      ],
      "pattern": "Color-block",
      "fit": "Regular",
      "material": "Canvas",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/shoes-cream-platform-sneakers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-cream-platform-sneakers.jpg"
    },
    {
      "id": "shoes-nude-patent-pumps",
      "name": "Nude Patent Pumps",
      "slot": "shoes",
      "category": "heels",
      "colors": [
        "Nude",
        "Blush"
      ],
      "pattern": "Solid",
      "fit": "Pointed toe",
      "material": "Patent leather",
      "formality": 4,
      "formalityBand": "business",
      "photo": "assets/wardrobe/thumbnails/shoes-nude-patent-pumps.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-nude-patent-pumps.jpg"
    },
    {
      "id": "shoes-white-platform-sneakers",
      "name": "White Platform Sneakers",
      "slot": "shoes",
      "category": "sneakers",
      "colors": [
        "White"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Leather",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/shoes-white-platform-sneakers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-white-platform-sneakers.jpg"
    },
    {
      "id": "shoes-beige-green-sneakers",
      "name": "Beige and Green Sneakers",
      "slot": "shoes",
      "category": "sneakers",
      "colors": [
        "Beige",
        "Green",
        "Brown"
      ],
      "pattern": "Striped trim",
      "fit": "Regular",
      "material": "Leather and textile",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/shoes-beige-green-sneakers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-beige-green-sneakers.jpg"
    },
    {
      "id": "shoes-brown-chukka-boots",
      "name": "Brown Chukka Boots",
      "slot": "shoes",
      "category": "boots",
      "colors": [
        "Brown",
        "Dark brown"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Leather",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/shoes-brown-chukka-boots.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-brown-chukka-boots.jpg"
    },
    {
      "id": "shoes-black-high-top-sneakers",
      "name": "Black High-top Sneakers",
      "slot": "shoes",
      "category": "sneakers",
      "colors": [
        "Black",
        "White"
      ],
      "pattern": "Color-block",
      "fit": "High top",
      "material": "Canvas",
      "formality": 1,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/shoes-black-high-top-sneakers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-black-high-top-sneakers.jpg"
    },
    {
      "id": "shoes-orange-leather-loafers",
      "name": "Orange Leather Loafers",
      "slot": "shoes",
      "category": "loafers",
      "colors": [
        "Orange",
        "Black"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Leather",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/shoes-orange-leather-loafers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-orange-leather-loafers.jpg"
    },
    {
      "id": "shoes-navy-suede-loafers",
      "name": "Navy Suede Loafers",
      "slot": "shoes",
      "category": "loafers",
      "colors": [
        "Navy",
        "Dark blue"
      ],
      "pattern": "Solid",
      "fit": "Regular",
      "material": "Suede",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/shoes-navy-suede-loafers.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-navy-suede-loafers.jpg"
    },
    {
      "id": "shoes-black-patent-pumps",
      "name": "Black Patent Pumps",
      "slot": "shoes",
      "category": "heels",
      "colors": [
        "Black"
      ],
      "pattern": "Solid",
      "fit": "Pointed toe",
      "material": "Patent leather",
      "formality": 5,
      "formalityBand": "formal",
      "photo": "assets/wardrobe/thumbnails/shoes-black-patent-pumps.jpg",
      "fullPhoto": "assets/wardrobe/shoes/shoes-black-patent-pumps.jpg"
    },
    {
      "id": "outerwear-white-utility-jacket",
      "name": "Off-white Utility Jacket",
      "slot": "outerwear",
      "category": "jacket",
      "colors": [
        "Off-white",
        "White"
      ],
      "pattern": "Solid",
      "fit": "Relaxed",
      "material": "Cotton blend",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/outerwear-white-utility-jacket.jpg",
      "fullPhoto": "assets/wardrobe/outerwear/outerwear-white-utility-jacket.jpg"
    },
    {
      "id": "outerwear-denim-jacket",
      "name": "Blue Denim Jacket",
      "slot": "outerwear",
      "category": "jacket",
      "colors": [
        "Blue",
        "Dark blue"
      ],
      "pattern": "Washed denim",
      "fit": "Regular",
      "material": "Denim",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/outerwear-denim-jacket.jpg",
      "fullPhoto": "assets/wardrobe/outerwear/outerwear-denim-jacket.jpg"
    },
    {
      "id": "outerwear-rust-overshirt",
      "name": "Rust Overshirt",
      "slot": "outerwear",
      "category": "overshirt",
      "colors": [
        "Rust",
        "Orange",
        "White"
      ],
      "pattern": "Solid",
      "fit": "Relaxed",
      "material": "Cotton",
      "formality": 3,
      "formalityBand": "smart_casual",
      "photo": "assets/wardrobe/thumbnails/outerwear-rust-overshirt.jpg",
      "fullPhoto": "assets/wardrobe/outerwear/outerwear-rust-overshirt.jpg"
    },
    {
      "id": "outerwear-white-belted-trench",
      "name": "White Belted Trench Coat",
      "slot": "outerwear",
      "category": "trench_coat",
      "colors": [
        "White",
        "Off-white"
      ],
      "pattern": "Solid",
      "fit": "Belted longline",
      "material": "Woven fabric",
      "formality": 4,
      "formalityBand": "business",
      "photo": "assets/wardrobe/thumbnails/outerwear-white-belted-trench.jpg",
      "fullPhoto": "assets/wardrobe/outerwear/outerwear-white-belted-trench.jpg"
    },
    {
      "id": "outerwear-gray-windbreaker",
      "name": "Charcoal Windbreaker",
      "slot": "outerwear",
      "category": "windbreaker",
      "colors": [
        "Charcoal",
        "White"
      ],
      "pattern": "Solid",
      "fit": "Relaxed",
      "material": "Nylon",
      "formality": 2,
      "formalityBand": "casual",
      "photo": "assets/wardrobe/thumbnails/outerwear-gray-windbreaker.jpg",
      "fullPhoto": "assets/wardrobe/outerwear/outerwear-gray-windbreaker.jpg"
    }
  ],
  "meta": {
    "assetVersion": "1.0.0",
    "warmthScoring": "pending_weather_module",
    "count": 28
  }
};
})();
