using IJuliaTimeMachine
using Documenter

cp(normpath(@__FILE__, "../../README.md"), normpath(@__FILE__, "../src/overview.md"); force=true)
cp(normpath(@__FILE__, "../../examples/Demo.pdf"), normpath(@__FILE__, "../src/Demo.pdf"); force=true)


makedocs(;
    modules=[IJuliaTimeMachine],
    authors="Daniel Spielman <daniel.spielman@yale.edu> and contributors",
    repo="https://github.com/danspielman/IJuliaTimeMachine.jl/blob/{commit}{path}#L{line}",
    sitename="IJuliaTimeMachine.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://danspielman.github.io/IJuliaTimeMachine.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Overview" => "overview.md",
        "Docstrings" => "docstrings.md"
    ],
)

deploydocs(;
    repo="github.com/danspielman/IJuliaTimeMachine.jl",
)

rm(normpath(@__FILE__, "../src/overview.md"))
rm(normpath(@__FILE__, "../src/Demo.pdf"))