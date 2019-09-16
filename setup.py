import setuptools

setuptools.setup(
    name="speech",
    version="0.2.1",
    description="Awni speech repo - install to make easier to import",
    author="Awni Hannun",
    packages=setuptools.find_packages('src'),
    package_dir={'': 'src'},
    url="https://github.com/awni/speech",
)
