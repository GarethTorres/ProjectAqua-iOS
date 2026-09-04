//
//  ItineraryParserTests.swift
//  ProjectAquaSwiftTests
//

import Testing
@testable import ProjectAquaSwift

struct ItineraryParserTests {
    let parser = ItineraryParser()

    // MARK: - A. New Mexico Regression Itinerary

    @Test func newMexicoRegressionItinerary() {
        let itinerary = """
        New Mexico

        NP CARD 6:50 PM Sunset

        Albuquerque
        Albuquerque International Balloon Fiesta
        10.3 - 10.4
        Sandia Peak Tramway
        Anderson Abruzzo Albuquerque International Balloon Museum
        Old Town Albuquerque

        Santa Fe
        Santa Fe Plaza
        Inn and Spa at Loretto
        Meow Wolf Santa Fe's House of Eternal Return
        Cathedral Basilica
        Canyon Road
        Georgia O'Keeffe Museum

        Carlsbad Caverns National Park
        White Sands National Park
        After 4PM
        Bandelier National Monument
        Kasha-Katuwe Tent Rocks National Monument
        PistachioLand
        15 hr drive

        Day 1
        Landing 3:30
        Sandia Peak Tramway sunset 1hr
        Around 5:30PM
        Stay in Santa Fe

        Day 2
        Santa Fe
        Georgia O'Keeffe Museum
        Santa Fe Plaza
        Cathedral Basilica
        Inn and Spa at Loretto
        Canyon Road
        Meow Wolf Santa Fe's House of Eternal Return 3 hrs 10AM–8PM
        Stay in Santa Fe

        Day 3
        Bandelier National Monument 3.5hr
        Visitor Center → Main Loop Trail → Pueblo 遗址 → cliff dwellings
        Kasha-Katuwe Tent Rocks National Monument 3hr
        slot canyon + tent rocks 地貌 + 登高看全景
        Stay in Abq

        Day 4
        Albuquerque
        Albuquerque International Balloon Fiesta
        Mass Ascension
        Balloon Glow
        Park & Ride
        Anderson Abruzzo Albuquerque International Balloon Museum 1hr
        Old Town Albuquerque
        Stay in Abq

        Day 5
        PistachioLand
        White Sands National Park 2hr
        around 4PM
        Stay in Alamogordo

        Day 6
        Carlsbad Caverns National Park 3hr
        Bat Flight Amphitheater 1.5hr
        Stay in Carlsbad

        Day 7
        Departure 4PM
        Back to Abq and take off
        """

        let result = parser.parse(itinerary)

        // Expected destinations (deduplicated)
        let expectedDestinations = [
            "Albuquerque International Balloon Fiesta",
            "Sandia Peak Tramway",
            "Anderson Abruzzo Albuquerque International Balloon Museum",
            "Old Town Albuquerque",
            "Santa Fe Plaza",
            "Inn and Spa at Loretto",
            "Meow Wolf Santa Fe's House of Eternal Return",
            "Cathedral Basilica",
            "Canyon Road",
            "Georgia O'Keeffe Museum",
            "Carlsbad Caverns National Park",
            "White Sands National Park",
            "Bandelier National Monument",
            "Kasha-Katuwe Tent Rocks National Monument",
            "PistachioLand",
            "Bat Flight Amphitheater",
            "Mass Ascension",
            "Balloon Glow",
            "Park & Ride"
        ]

        let actualNames = Set(result.destinations.map(\.displayName))

        // Core POIs should be present
        #expect(actualNames.contains("Albuquerque International Balloon Fiesta"))
        #expect(actualNames.contains("Sandia Peak Tramway"))
        #expect(actualNames.contains("Anderson Abruzzo Albuquerque International Balloon Museum"))
        #expect(actualNames.contains("Old Town Albuquerque"))
        #expect(actualNames.contains("Santa Fe Plaza"))
        #expect(actualNames.contains("Inn and Spa at Loretto"))
        #expect(actualNames.contains("Meow Wolf Santa Fe's House of Eternal Return"))
        #expect(actualNames.contains("Cathedral Basilica"))
        #expect(actualNames.contains("Canyon Road"))
        #expect(actualNames.contains("Georgia O'Keeffe Museum"))
        #expect(actualNames.contains("Carlsbad Caverns National Park"))
        #expect(actualNames.contains("White Sands National Park"))
        #expect(actualNames.contains("Bandelier National Monument"))
        #expect(actualNames.contains("Kasha-Katuwe Tent Rocks National Monument"))
        #expect(actualNames.contains("PistachioLand"))
        #expect(actualNames.contains("Bat Flight Amphitheater"))

        // Cities should NOT be destinations
        #expect(!actualNames.contains("New Mexico"))
        #expect(!actualNames.contains("Albuquerque"))
        #expect(!actualNames.contains("Santa Fe"))
        #expect(!actualNames.contains("Alamogordo"))
        #expect(!actualNames.contains("Carlsbad"))
        #expect(!actualNames.contains("Abq"))

        // Days should be detected
        #expect(result.detectedDays.contains(1))
        #expect(result.detectedDays.contains(7))

        // Contexts should include cities
        let contextNames = Set(result.contexts.map(\.name))
        #expect(contextNames.contains("New Mexico") || contextNames.contains("Albuquerque") || contextNames.contains("Santa Fe"))
    }

    // MARK: - B. Duplicate Test

    @Test func duplicateDestination() {
        let itinerary = """
        Santa Fe Plaza
        Santa Fe Plaza
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.count == 1)
        #expect(result.destinations.first?.displayName == "Santa Fe Plaza")
    }

    // MARK: - C. Unicode Apostrophe Test

    @Test func unicodeApostropheNormalization() {
        let itinerary = """
        Georgia O'Keeffe Museum
        Georgia O'Keeffe Museum
        """

        let result = parser.parse(itinerary)

        // Should deduplicate despite different apostrophes
        #expect(result.destinations.count == 1)
    }

    // MARK: - D. Day Inheritance Test

    @Test func dayInheritance() {
        let itinerary = """
        Day 3
        Bandelier National Monument
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.count == 1)
        #expect(result.destinations.first?.day == 3)
    }

    // MARK: - E. Stay Line Test

    @Test func stayLineNotDestination() {
        let itinerary = """
        Stay in Santa Fe
        Stay in Abq
        Stay in Alamogordo
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
    }

    // MARK: - F. Time Line Test

    @Test func timeLineNotDestination() {
        let itinerary = """
        Around 5:30PM
        After 4PM
        Landing 3:30
        10.3 - 10.4
        15 hr drive
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
    }

    // MARK: - G. Mixed Language Note Test

    @Test func mixedLanguageNoteNotDestination() {
        let itinerary = """
        slot canyon + tent rocks 地貌 + 登高看全景
        Visitor Center → Main Loop Trail → Pueblo 遗址 → cliff dwellings
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
    }

    // MARK: - Additional Tests

    @Test func durationStrippedFromDestination() {
        let itinerary = """
        Sandia Peak Tramway sunset 1hr
        White Sands National Park 2hr
        Bandelier National Monument 3.5hr
        Meow Wolf Santa Fe's House of Eternal Return 3 hrs 10AM–8PM
        """

        let result = parser.parse(itinerary)

        let names = result.destinations.map(\.displayName)

        #expect(names.contains("Sandia Peak Tramway sunset"))
        #expect(names.contains("White Sands National Park"))
        #expect(names.contains("Bandelier National Monument"))
        #expect(names.contains("Meow Wolf Santa Fe's House of Eternal Return"))

        // Should not contain raw duration text
        for name in names {
            #expect(!name.hasSuffix("hr"))
            #expect(!name.hasSuffix("hrs"))
            #expect(!name.contains("10AM"))
        }
    }

    @Test func dayHeaderNotDestination() {
        let itinerary = """
        Day 1
        Day 2
        Day 7
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
        #expect(result.detectedDays.count == 3)
    }

    @Test func cityContextDetection() {
        let itinerary = """
        Santa Fe
        Santa Fe Plaza
        Georgia O'Keeffe Museum
        """

        let result = parser.parse(itinerary)

        // Santa Fe should be context, not destination
        let destNames = result.destinations.map(\.displayName)
        #expect(!destNames.contains("Santa Fe"))
        #expect(destNames.contains("Santa Fe Plaza"))
        #expect(destNames.contains("Georgia O'Keeffe Museum"))

        // Santa Fe should be a geographic context
        let contextNames = result.contexts.map(\.name)
        #expect(contextNames.contains("Santa Fe"))
    }

    @Test func geographicContextInheritance() {
        let itinerary = """
        Santa Fe
        Santa Fe Plaza
        Cathedral Basilica
        """

        let result = parser.parse(itinerary)

        // Destinations should inherit Santa Fe context
        for dest in result.destinations {
            #expect(dest.geographicContext == "Santa Fe")
        }
    }

    @Test func multipleContextSections() {
        let itinerary = """
        Santa Fe
        Santa Fe Plaza

        Albuquerque
        Old Town Albuquerque
        """

        let result = parser.parse(itinerary)

        let santaFeDest = result.destinations.first { $0.displayName == "Santa Fe Plaza" }
        let abqDest = result.destinations.first { $0.displayName == "Old Town Albuquerque" }

        #expect(santaFeDest?.geographicContext == "Santa Fe")
        #expect(abqDest?.geographicContext == "Albuquerque")
    }

    @Test func npCardLineIgnored() {
        let itinerary = """
        NP CARD 6:50 PM Sunset
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
    }

    @Test func departureLineIgnored() {
        let itinerary = """
        Departure 4PM
        Back to Abq and take off
        """

        let result = parser.parse(itinerary)

        #expect(result.destinations.isEmpty)
    }

    @Test func emptyItinerary() {
        let result = parser.parse("")

        #expect(result.destinations.isEmpty)
        #expect(result.contexts.isEmpty)
        #expect(result.detectedDays.isEmpty)
    }

    @Test func lineClassificationDayHeader() {
        #expect(parser.classifyLine("Day 1") == .dayHeader(day: 1))
        #expect(parser.classifyLine("Day 7") == .dayHeader(day: 7))
        #expect(parser.classifyLine("Day 10") == .dayHeader(day: 10))
    }

    @Test func lineClassificationStay() {
        #expect(parser.classifyLine("Stay in Santa Fe") == .stayContext)
        #expect(parser.classifyLine("Stay in Abq") == .stayContext)
        #expect(parser.classifyLine("Staying at Hotel") == .stayContext)
    }

    @Test func lineClassificationTime() {
        #expect(parser.classifyLine("Around 5:30PM") == .time)
        #expect(parser.classifyLine("After 4PM") == .time)
        #expect(parser.classifyLine("10.3 - 10.4") == .time)
        #expect(parser.classifyLine("15 hr drive") == .time)
        #expect(parser.classifyLine("Landing 3:30") == .time)
    }

    @Test func lineClassificationRouteInstruction() {
        #expect(parser.classifyLine("Visitor Center → Main Loop Trail → Pueblo 遗址 → cliff dwellings") == .routeInstruction)
    }

    @Test func lineClassificationNote() {
        #expect(parser.classifyLine("slot canyon + tent rocks 地貌 + 登高看全景") == .note)
    }

    @Test func normalizeForDeduplication() {
        let normalized1 = parser.normalizeForDeduplication("Georgia O'Keeffe Museum")
        let normalized2 = parser.normalizeForDeduplication("Georgia O'Keeffe Museum")

        #expect(normalized1 == normalized2)
    }

    @Test func destinationNameNormalization() {
        #expect(parser.normalizeDestinationName("White Sands National Park 2hr") == "White Sands National Park")
        #expect(parser.normalizeDestinationName("Bandelier National Monument 3.5hr") == "Bandelier National Monument")
        #expect(parser.normalizeDestinationName("Meow Wolf 3 hrs 10AM–8PM") == "Meow Wolf")
    }
}
