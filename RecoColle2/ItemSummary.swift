//
//	ItemSummary.swift
//	Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

import Foundation

struct ItemSummary : Decodable {

	let additionalImages : [AdditionalImage]?
	let adultOnly : Bool?
	let availableCoupons : Bool?
	let bidCount : Int?
	let buyingOptions : [String]?
	let categories : [Category]?
	let condition : String?
	let conditionId : String?
	let currentBidPrice : CurrentBidPrice?
	let image : Image?
	let itemAffiliateWebUrl : String?
	let itemCreationDate : String?
	let itemEndDate : String?
	let itemGroupHref : String?
	let itemGroupType : String?
	let itemHref : String?
	let itemId : String?
	let itemLocation : ItemLocation?
	let itemWebUrl : String?
	let leafCategoryIds : [String]?
	let legacyItemId : String?
	let listingMarketplaceId : String?
//    let price : CurrentBidPrice?
    let price : Price?
	let priorityListing : Bool?
	let seller : Seller?
	let shippingOptions : [ShippingOption]?
	let thumbnailImages : [AdditionalImage]?
	let title : String?
	let topRatedBuyingExperience : Bool?


	enum CodingKeys: String, CodingKey {
		case additionalImages = "additionalImages"
		case adultOnly = "adultOnly"
		case availableCoupons = "availableCoupons"
		case bidCount = "bidCount"
		case buyingOptions = "buyingOptions"
		case categories = "categories"
		case condition = "condition"
		case conditionId = "conditionId"
		case currentBidPrice = "currentBidPrice"
		case image = "image"
		case itemAffiliateWebUrl = "itemAffiliateWebUrl"
		case itemCreationDate = "itemCreationDate"
		case itemEndDate = "itemEndDate"
		case itemGroupHref = "itemGroupHref"
		case itemGroupType = "itemGroupType"
		case itemHref = "itemHref"
		case itemId = "itemId"
		case itemLocation = "itemLocation"
		case itemWebUrl = "itemWebUrl"
		case leafCategoryIds = "leafCategoryIds"
		case legacyItemId = "legacyItemId"
		case listingMarketplaceId = "listingMarketplaceId"
		case price = "price"
		case priorityListing = "priorityListing"
		case seller = "seller"
		case shippingOptions = "shippingOptions"
		case thumbnailImages = "thumbnailImages"
		case title = "title"
		case topRatedBuyingExperience = "topRatedBuyingExperience"
	}
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		additionalImages = try values.decodeIfPresent([AdditionalImage].self, forKey: .additionalImages)
		adultOnly = try values.decodeIfPresent(Bool.self, forKey: .adultOnly)
		availableCoupons = try values.decodeIfPresent(Bool.self, forKey: .availableCoupons)
		bidCount = try values.decodeIfPresent(Int.self, forKey: .bidCount)
		buyingOptions = try values.decodeIfPresent([String].self, forKey: .buyingOptions)
		categories = try values.decodeIfPresent([Category].self, forKey: .categories)
		condition = try values.decodeIfPresent(String.self, forKey: .condition)
		conditionId = try values.decodeIfPresent(String.self, forKey: .conditionId)
//		currentBidPrice = try CurrentBidPrice(from: decoder)
        currentBidPrice = try values.decodeIfPresent(CurrentBidPrice.self, forKey: .currentBidPrice)
//		image = try AdditionalImage(from: decoder)
        image = try values.decodeIfPresent(Image.self, forKey: .image)
		itemAffiliateWebUrl = try values.decodeIfPresent(String.self, forKey: .itemAffiliateWebUrl)
		itemCreationDate = try values.decodeIfPresent(String.self, forKey: .itemCreationDate)
		itemEndDate = try values.decodeIfPresent(String.self, forKey: .itemEndDate)
		itemGroupHref = try values.decodeIfPresent(String.self, forKey: .itemGroupHref)
		itemGroupType = try values.decodeIfPresent(String.self, forKey: .itemGroupType)
		itemHref = try values.decodeIfPresent(String.self, forKey: .itemHref)
		itemId = try values.decodeIfPresent(String.self, forKey: .itemId)
//		itemLocation = try ItemLocation(from: decoder)
        itemLocation = try values.decodeIfPresent(ItemLocation.self, forKey: .itemLocation)
		itemWebUrl = try values.decodeIfPresent(String.self, forKey: .itemWebUrl)
		leafCategoryIds = try values.decodeIfPresent([String].self, forKey: .leafCategoryIds)
		legacyItemId = try values.decodeIfPresent(String.self, forKey: .legacyItemId)
		listingMarketplaceId = try values.decodeIfPresent(String.self, forKey: .listingMarketplaceId)
//		price = try CurrentBidPrice(from: decoder)
        price = try values.decodeIfPresent(Price.self, forKey: .price)
		priorityListing = try values.decodeIfPresent(Bool.self, forKey: .priorityListing)
//		seller = try Seller(from: decoder)
        seller = try values.decodeIfPresent(Seller.self, forKey: .seller)
		shippingOptions = try values.decodeIfPresent([ShippingOption].self, forKey: .shippingOptions)
		thumbnailImages = try values.decodeIfPresent([AdditionalImage].self, forKey: .thumbnailImages)
		title = try values.decodeIfPresent(String.self, forKey: .title)
		topRatedBuyingExperience = try values.decodeIfPresent(Bool.self, forKey: .topRatedBuyingExperience)
	}


}
