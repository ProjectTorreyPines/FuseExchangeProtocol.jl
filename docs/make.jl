using Documenter
import FuseExchangeProtocol

# Call functions
open(joinpath(@__DIR__, "src/api.md"), "w") do f
    println(f, "# API Reference\n")
    for page in keys(FuseExchangeProtocol.document)
        if page == :Expressions
            continue
        end
        println(f, "## $page\n")
        println(f, "```@docs")
        for item in FuseExchangeProtocol.document[page]
            println(f, "$item")
        end
        println(f, "```")
    end
end

makedocs(;
    modules=[FuseExchangeProtocol],
    format=Documenter.HTML(),
    sitename="FuseExchangeProtocol",
    checkdocs=:none,
    pages=["index.md", "api.md", "License" => "license.md", "Notice" => "notice.md"]
)

# Deploy docs
# This function deploys the documentation to the gh-pages branch of the repository.
# The main documentation that will be hosted on
# https://projecttorreypines.github.io/FuseExchangeProtocol.jl/stable
# will be built from latest release tagged with a version number.
# The development documentation that will be hosted on
# https://projecttorreypines.github.io/FuseExchangeProtocol.jl/dev
# will be built from the latest commit on the chosen devbranch argument below.
# For testing purposes, the devbranch argument can be set to WIP branch like "docs".
# While merging with master, the devbranch argument should be set to "master".
deploydocs(;
    repo="github.com/ProjectTorreyPines/FuseExchangeProtocol.jl.git",
    target="build",
    branch="gh-pages",
    devbranch="master",
    versions=["stable" => "v^", "v#.#"]
)